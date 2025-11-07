class MessagesController < ApplicationController
  before_action :auto_enable_ai_for_partner
  guard_feature unless: -> { Current.user.ai_enabled? }

  before_action :set_chat

  def create
    @message = UserMessage.create!(
      chat: @chat,
      content: message_params[:content],
      ai_model: message_params[:ai_model]
    )

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to chat_path(@chat) }
    end
  end

  private
    def set_chat
      @chat = Current.user.chats.find(params[:chat_id])
    end

    def message_params
      params.require(:message).permit(:content, :ai_model)
    end

    def auto_enable_ai_for_partner
      user = Current.user
      return unless user
      return if user.ai_enabled?
      return unless user.ai_available?

      ids = partner_vector_store_ids(user)
      return if ids.blank?

      user.update(ai_enabled: true)
    end

    def partner_vector_store_ids(user)
      ids = user.partner_metadata.fetch("vector_store_id_array", [])

      if ids.blank? && user.partner_key.present?
        partner_defaults = Partners.find(user.partner_key)&.default_metadata
        ids = partner_defaults.fetch("vector_store_id_array", []) if partner_defaults
      end

      Array(ids).compact_blank
    end
end
