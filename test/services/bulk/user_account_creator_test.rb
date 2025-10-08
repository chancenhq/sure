require "test_helper"

class Bulk::UserAccountCreatorTest < ActiveSupport::TestCase
  setup do
    Partners.reset!
    @partner = Partners.find("chancen-ke")
    @creator = Bulk::UserAccountCreator.new(partner: @partner)
  end

  test "creates a family and admin user with partner defaults" do
    result = @creator.call("new-partner-user@example.com")

    assert_equal :created, result.status

    user = result.user
    assert user.persisted?
    assert_equal "new-partner-user@example.com", user.email
    assert_equal "chancen-ke", user.partner_key
    assert_equal "KES", user.family.currency
    assert_equal "%d/%m/%Y", user.family.date_format
    assert_equal "intro", user.ui_layout
    assert user.ai_enabled?
    assert_equal "Chancen Kenya", user.partner_name
  end

  test "skips existing users" do
    existing_email = users(:empty).email

    result = @creator.call(existing_email)

    assert_equal :skipped, result.status
    assert_equal "User already exists", result.message
  end

  test "returns an error for invalid emails" do
    result = @creator.call("invalid-email")

    assert_equal :error, result.status
    assert_equal "Invalid email format", result.message
  end
end
