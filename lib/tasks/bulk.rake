require "json"

namespace :bulk do
  desc "Create empty partner accounts for a list of email addresses"
  task :add_users, [:partner_key, :emails] => :environment do |_task, args|
    args.with_defaults(
      partner_key: ENV["partner_key"] || ENV["PARTNER_KEY"],
      emails: ENV["emails"] || ENV["EMAILS"]
    )

    partner_key = args[:partner_key].to_s.strip

    if partner_key.blank?
      abort "Partner key is required. Provide as rake bulk:add_users[partner_key,emails] or PARTNER_KEY=..."
    end

    partner = Partners.find(partner_key)

    unless partner
      available = Partners.all.keys
      abort "Unknown partner '#{partner_key}'. Available partners: #{available.join(", ")}"
    end

    raw_emails = parse_emails_argument(args[:emails])

    if raw_emails.empty?
      abort "No email addresses provided. Pass a JSON array or comma-separated list as the second argument."
    end

    creator = Bulk::UserAccountCreator.new(partner: partner)

    summary = Hash.new(0)

    raw_emails.each do |email|
      result = creator.call(email)
      status = result.status || :unknown
      summary[status] += 1

      case status
      when :created
        puts "✅ Created account for #{result.email}"
      when :skipped
        puts "⚠️  Skipped #{result.email.presence || email}: #{result.message}"
      when :error
        message = result.message || result.error&.message || "Unknown error"
        puts "❌ Failed to create account for #{result.email.presence || email}: #{message}"
      else
        puts "⚠️  Received unexpected status '#{result.status}' for #{result.email.presence || email}"
      end
    end

    puts
    puts "Summary:"
    puts "  Created: #{summary[:created]}"
    puts "  Skipped: #{summary[:skipped]}"
    puts "  Errors:  #{summary[:error]}"

    exit(1) if summary[:error].positive?
  end

  def parse_emails_argument(argument)
    value = argument

    if value.respond_to?(:to_a) && !value.is_a?(String)
      list = value.to_a
    else
      raw = value.to_s.strip
      return [] if raw.blank?

      list = parse_json_array(raw) || raw.split(/[,;\s]+/)
    end

    list.filter_map { |item| item.to_s.strip.presence }.uniq
  end

  def parse_json_array(value)
    parsed = JSON.parse(value)
    return parsed if parsed.is_a?(Array)

    nil
  rescue JSON::ParserError
    nil
  end
end
