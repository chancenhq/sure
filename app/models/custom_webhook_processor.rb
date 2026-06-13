class ChoiceWebhookProcessor
  def initialize(webhook_body)
    @webhook_body = webhook_body
    @parsed_body = JSON.parse(webhook_body)
  end

  def process
    case webhook_type
    when "user.created"
      handle_user_created
    when "user.updated"
      handle_user_updated
    when "payment.completed"
      handle_payment_completed
    when "subscription.cancelled"
      handle_subscription_cancelled
    else
      Rails.logger.warn("Unhandled custom webhook type: #{webhook_type}")
    end
  rescue => e
    # Always ensure we return a 200 to keep endpoint healthy
    Sentry.capture_exception(e) do |scope|
      scope.set_tags(webhook_type: webhook_type, webhook_id: webhook_id)
    end
  end

  private
    attr_reader :webhook_body, :parsed_body

    def webhook_type
      @webhook_type ||= parsed_body["type"]
    end

    def webhook_id
      @webhook_id ||= parsed_body["id"]
    end

    def webhook_data
      @webhook_data ||= parsed_body["data"] || {}
    end

    def handle_user_created
      Rails.logger.info("Processing user.created webhook: #{webhook_id}")
      
      # Example: Create or update user record
      # User.find_or_create_by(external_id: webhook_data["user_id"]) do |user|
      #   user.email = webhook_data["email"]
      #   user.name = webhook_data["name"]
      # end
    end

    def handle_user_updated
      Rails.logger.info("Processing user.updated webhook: #{webhook_id}")
      
      # Example: Update user record
      # user = User.find_by(external_id: webhook_data["user_id"])
      # user&.update!(
      #   email: webhook_data["email"],
      #   name: webhook_data["name"]
      # )
    end

    def handle_payment_completed
      Rails.logger.info("Processing payment.completed webhook: #{webhook_id}")
      
      # Example: Process payment
      # payment = Payment.find_or_create_by(external_id: webhook_data["payment_id"]) do |p|
      #   p.amount = webhook_data["amount"]
      #   p.currency = webhook_data["currency"]
      #   p.status = "completed"
      # end
    end

    def handle_subscription_cancelled
      Rails.logger.info("Processing subscription.cancelled webhook: #{webhook_id}")
      
      # Example: Cancel subscription
      # subscription = Subscription.find_by(external_id: webhook_data["subscription_id"])
      # subscription&.update!(status: "cancelled")
    end
end 