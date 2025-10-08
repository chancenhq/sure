require "test_helper"
require "rake"

class BulkAddUsersTaskTest < ActiveSupport::TestCase
  setup do
    Rake.application = Rake::Application.new
    load Rails.root.join("lib/tasks/bulk.rake")
  end

  test "parse_emails_argument handles comma separated string" do
    result = send(:parse_emails_argument, "one@example.com,two@example.com")
    assert_equal ["one@example.com", "two@example.com"], result
  end

  test "parse_emails_argument handles json array" do
    result = send(:parse_emails_argument, '["one@example.com","two@example.com"]')
    assert_equal ["one@example.com", "two@example.com"], result
  end

  test "task arguments collect positional emails" do
    args = Rake::TaskArguments.new([:partner_key, :emails], ["partner", "one@example.com", "two@example.com"])
    args.with_defaults(partner_key: nil, emails: nil)

    email_inputs = [args[:emails]]
    email_inputs.concat(args.extras) if args.respond_to?(:extras)

    result = email_inputs.flat_map { |value| send(:parse_emails_argument, value) }.uniq

    assert_equal ["one@example.com", "two@example.com"], result
  end
end
