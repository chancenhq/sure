class UserMessage < Message
  validates :ai_model, presence: true

  after_create_commit :request_response_later

  def role
    "user"
  end

  def request_response_later
    enable_ai_if_available
    chat.ask_assistant_later(self)
  end

  def request_response
    chat.ask_assistant(self)
  end

  private
    def enable_ai_if_available
      user = chat.user
      return if user.ai_enabled?
      return unless user.ai_available?

      user.update(ai_enabled: true)
    end
end
