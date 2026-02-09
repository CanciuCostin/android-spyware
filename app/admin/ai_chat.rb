require_dependency 'ai_chat'

ActiveAdmin.register_page "AI Chat" do
  menu label: "🤖 AI Chat", parent: "🧠 AI", priority: 1

  content do
    render partial: 'admin/ai_chat'
  end

  page_action :send_message, method: :post do
    device_id = params[:device_id]
    message = params[:message]
    history = params[:history] || []

    if device_id.blank? || message.blank?
      return render json: { role: 'assistant', content: '❌ Моля, изберете устройство и напишете съобщение.' }
    end

    result = AiChat.chat(device_id, message, conversation_history: history)
    render json: result
  end
end
