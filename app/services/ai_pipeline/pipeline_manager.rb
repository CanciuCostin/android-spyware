# frozen_string_literal: true

module AiPipeline
  class PipelineManager
    PRIORITIES = { critical: 0, high: 1, normal: 2, low: 3 }.freeze

    attr_reader :processors, :stats

    def initialize
      @processors = []
      @queue = Queue.new
      @stats = { processed: 0, errors: 0, started_at: Time.current }
      @mutex = Mutex.new
      @running = false
    end

    # Register a processor plugin for a specific stage
    def register(processor, stage: :default, priority: :normal)
      @mutex.synchronize do
        @processors << {
          processor: processor,
          stage: stage,
          priority: PRIORITIES.fetch(priority, 2)
        }
        @processors.sort_by! { |p| p[:priority] }
      end
      self
    end

    # Enqueue device data for processing
    def enqueue(device_id, data_type, payload, priority: :normal)
      item = {
        id: SecureRandom.uuid,
        device_id: device_id,
        data_type: data_type,
        payload: payload,
        priority: PRIORITIES.fetch(priority, 2),
        enqueued_at: Time.current
      }

      @queue << item
      broadcast_status(:enqueued, item)
      item[:id]
    end

    # Process a single data item through all registered stages
    def process(device_id, data_type, payload)
      context = build_context(device_id, data_type, payload)

      sorted_processors = @mutex.synchronize { @processors.dup }

      sorted_processors.each do |entry|
        processor = entry[:processor]
        next unless processor.handles?(data_type)

        begin
          context = processor.process(context)
        rescue StandardError => e
          Rails.logger.error("[AiPipeline] Processor #{processor.class.name} failed: #{e.message}")
          context[:errors] << { processor: processor.class.name, error: e.message }
          @mutex.synchronize { @stats[:errors] += 1 }
        end
      end

      @mutex.synchronize { @stats[:processed] += 1 }
      broadcast_status(:completed, context)
      context
    end

    # Process all queued items (batch mode)
    def process_queue
      results = []
      until @queue.empty?
        item = @queue.pop(true) rescue nil
        break unless item

        result = process(item[:device_id], item[:data_type], item[:payload])
        results << result
      end
      results
    end

    # Start continuous processing in a background thread
    def start
      return if @running

      @running = true
      @worker = Thread.new do
        while @running
          begin
            item = @queue.pop(true) rescue nil
            if item
              process(item[:device_id], item[:data_type], item[:payload])
            else
              sleep 0.1
            end
          rescue StandardError => e
            Rails.logger.error("[AiPipeline] Worker error: #{e.message}")
          end
        end
      end
    end

    def stop
      @running = false
      @worker&.join(5)
    end

    def status
      @mutex.synchronize do
        {
          running: @running,
          processors: @processors.map { |p| p[:processor].class.name },
          queue_size: @queue.size,
          stats: @stats.merge(uptime_seconds: (Time.current - @stats[:started_at]).to_i)
        }
      end
    end

    private

    def build_context(device_id, data_type, payload)
      {
        id: SecureRandom.uuid,
        device_id: device_id,
        data_type: data_type,
        payload: payload,
        metadata: {},
        enrichments: {},
        anomalies: [],
        errors: [],
        started_at: Time.current
      }
    end

    def broadcast_status(event, data)
      ActionCable.server.broadcast(
        "ai_pipeline:#{data[:device_id]}",
        { event: event, data: data.except(:payload) }
      )
    rescue StandardError => e
      Rails.logger.debug("[AiPipeline] Broadcast skipped: #{e.message}")
    end
  end
end
