ActiveAdmin.register Recording do
  menu parent: "📦 Data", priority: 6, label: "🎵 Recordings"
  permit_params :date, :duration, :filename, :smartphone_id, :recording_type, :call_number, :call_direction, :strategy

  includes :smartphone

  scope :all, default: true
  scope("📞 Calls") { |s| s.where(recording_type: 'call') }
  scope("🎤 Audio") { |s| s.where.not(recording_type: 'call') }

  filter :smartphone
  filter :recording_type, as: :select, collection: ['audio', 'call', 'ambient']
  filter :call_direction, as: :select, collection: ['incoming', 'outgoing']
  filter :date

  index do
    selectable_column
    id_column
    column :smartphone
    column("Type") { |r| r.recording_type == 'call' ? '📞 Call' : '🎤 Audio' }
    column :call_number
    column("Direction") { |r|
      case r.call_direction
      when 'incoming' then '📥 Incoming'
      when 'outgoing' then '📤 Outgoing'
      else '-'
      end
    }
    column :duration
    column :strategy
    column :filename
    column :date
    column("Play") { |r|
      if r.filename.present?
        audio_path = "/files/dumps/audio/#{r.filename}"
        raw("<audio controls preload='none' style='height:30px;width:200px'><source src='#{audio_path}'></audio>")
      end
    }
    actions
  end

  show do
    attributes_table do
      row :id
      row :smartphone
      row("Type") { |r| r.recording_type == 'call' ? '📞 Call Recording' : '🎤 Audio Recording' }
      row :call_number
      row("Direction") { |r|
        case r.call_direction
        when 'incoming' then '📥 Incoming'
        when 'outgoing' then '📤 Outgoing'
        else '-'
        end
      }
      row :duration
      row :strategy
      row :filename
      row :date
      row("Audio Player") { |r|
        if r.filename.present?
          audio_path = "/files/dumps/audio/#{r.filename}"
          raw("<audio controls><source src='#{audio_path}'></audio>")
        end
      }
      row :created_at
      row :updated_at
    end
  end

  form do |f|
    f.semantic_errors
    f.inputs do
      f.input :smartphone, collection: Smartphone.all, include_blank: false
      f.input :recording_type, as: :select, collection: ['audio', 'call', 'ambient']
      f.input :call_number
      f.input :call_direction, as: :select, collection: ['incoming', 'outgoing']
      f.input :filename
      f.input :duration
      f.input :strategy
      f.input :date, as: :string, input_html: { type: :date }
    end
    f.actions
  end
end
