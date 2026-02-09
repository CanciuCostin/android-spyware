# frozen_string_literal: true

# Channel concern for batching broadcast messages.
# Include in any channel that sends frequent updates to reduce
# WebSocket frame overhead.
#
# Usage:
#   class MyChannel < ApplicationCable::Channel
#     include MessageBatching
#
#     def some_action(data)
#       batched_broadcast("stream_name", { type: 'update', data: data })
#     end
#   end
module MessageBatching
  extend ActiveSupport::Concern

  # Messages with these types bypass batching and are sent immediately
  PRIORITY_TYPES = %w[
    command
    command_response
    error
    disconnect
    ping
    pong
  ].freeze

  BATCH_INTERVAL = 0.1   # seconds
  MAX_BATCH_SIZE = 50     # messages

  included do
    after_subscribe :initialize_batch_state
  end

  # Queue a message for batched delivery. Priority messages
  # (commands, errors, pings) bypass the batch and send immediately.
  def batched_broadcast(stream, message)
    msg_type = message[:type] || message['type']

    if PRIORITY_TYPES.include?(msg_type.to_s)
      ActionCable.server.broadcast(stream, message)
      return
    end

    WebsocketOptimizer.enqueue(stream, message, max_batch_size: MAX_BATCH_SIZE)
  end

  # Force-flush any pending batched messages for a stream.
  def flush_batched(stream)
    WebsocketOptimizer.flush_batch(stream)
  end

  # Broadcast with automatic compression for large payloads.
  def smart_broadcast(stream, message)
    WebsocketOptimizer.smart_broadcast(stream, message)
  end

  private

  def initialize_batch_state
    # Batch state is managed in Redis via WebsocketOptimizer
  end
end
