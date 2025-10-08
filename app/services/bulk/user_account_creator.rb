require "securerandom"
require "uri"

module Bulk
  class UserAccountCreator
    Result = Struct.new(:status, :email, :user, :message, :error, keyword_init: true)

    FAMILY_ATTRIBUTE_KEYS = %w[currency locale country date_format timezone].freeze

    def initialize(partner:)
      raise ArgumentError, "partner is required" if partner.blank?

      @partner = partner
      ensure_required_metadata_present!
    end

    def call(email)
      normalized_email = normalize_email(email)

      if normalized_email.blank?
        return Result.new(status: :skipped, email: normalized_email, message: "Email is blank")
      end

      unless valid_email?(normalized_email)
        return Result.new(status: :error, email: normalized_email.presence || email.to_s, message: "Invalid email format")
      end

      if User.exists?(email: normalized_email)
        return Result.new(status: :skipped, email: normalized_email, message: "User already exists")
      end

      user = nil

      ActiveRecord::Base.transaction do
        family = create_family!(normalized_email)
        user = build_user(family, normalized_email)
        user.save!
      end

      Result.new(status: :created, email: normalized_email, user: user)
    rescue ActiveRecord::RecordInvalid => error
      Result.new(
        status: :error,
        email: normalized_email,
        error: error,
        message: error.record.errors.full_messages.to_sentence.presence || error.message
      )
    end

    private

      attr_reader :partner

      def normalize_email(email)
        email.to_s.strip.downcase
      end

      def valid_email?(email)
        URI::MailTo::EMAIL_REGEXP.match?(email)
      end

      def create_family!(email)
        attributes = family_attributes_for(email)
        Family.create!(attributes)
      end

      def build_user(family, email)
        user = family.users.new(
          email: email,
          role: :admin,
          password: SecureRandom.hex(16)
        )

        apply_partner_defaults(user)
        user
      end

      def apply_partner_defaults(user)
        metadata = partner_metadata_for_user

        if (layout = metadata.delete("ui_layout"))
          layout = layout.presence
          user.ui_layout = layout if layout
        end

        user.partner_metadata = metadata if metadata.present?

        partner.user_defaults.each do |attribute, value|
          setter = "#{attribute}="
          next unless user.respond_to?(setter)

          current_value = user.respond_to?(attribute) ? user.public_send(attribute) : nil
          next if current_value == value

          user.public_send(setter, value)
        end
      end

      def partner_metadata_for_user
        metadata = partner.default_metadata.deep_dup
        metadata["key"] ||= partner.key
        metadata["name"] ||= partner.name
        metadata["type"] ||= partner.type
        metadata
      end

      def family_attributes_for(email)
        metadata = partner.default_metadata
        attributes = metadata.slice(*FAMILY_ATTRIBUTE_KEYS).compact
        attributes.transform_keys!(&:to_sym)
        attributes[:name] = default_family_name(email)
        attributes
      end

      def default_family_name(email)
        local_part = email.to_s.split("@").first
        return email if local_part.blank?

        normalized = local_part.tr("._-", " ").squeeze(" ").strip
        return "#{normalized.titleize} Household" if normalized.present?

        email
      end

      def ensure_required_metadata_present!
        metadata = partner_metadata_for_user
        missing = partner.required_metadata_keys - metadata.keys

        return if missing.empty?

        raise ArgumentError, "Partner #{partner.key} is missing required metadata keys: #{missing.join(", ")}"
      end
  end
end
