class MessagesController < ApplicationController
  guard_feature unless: -> { Current.user.ai_enabled? }

  before_action :set_chat

  def create
    content = message_params[:content].to_s.strip

    if content.blank?
      flash[:alert] = t(".blank_content")
      redirect_to chat_path(@chat)
      return
    end

    @message = UserMessage.create!(
      chat: @chat,
      content: content,
      ai_model: message_params[:ai_model]
    )

    redirect_to chat_path(@chat, thinking: true)
  end

  private
    def set_chat
      @chat = Current.user.chats.find(params[:chat_id])
    end

    def message_params
      params.require(:message).permit(:content, :ai_model)
    end
end
