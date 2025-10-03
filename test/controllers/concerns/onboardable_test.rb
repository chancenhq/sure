require "test_helper"

class OnboardableTest < ActionDispatch::IntegrationTest
  setup do
    Partners.reset!
    sign_in @user = users(:empty)
    @user.family.subscription.destroy
  end

  teardown do
    Partners.reset!
  end

  test "must complete onboarding before any other action" do
    @user.update!(onboarded_at: nil)

    get root_path
    assert_redirected_to onboarding_path
  end

  test "must have subscription to visit dashboard" do
    @user.update!(onboarded_at: 1.day.ago)

    get root_path
    assert_redirected_to trial_onboarding_path
  end

  test "onboarded subscribed user can visit dashboard" do
    @user.update!(onboarded_at: 1.day.ago)
    @user.family.start_trial_subscription!

    get root_path
    assert_response :success
  end

  test "partner user must complete partner onboarding before any other action" do
    partner = Partners.default
    @user.update!(onboarded_at: nil, partner_metadata: partner.default_metadata)

    get root_path
    assert_redirected_to partner_onboarding_path(partner_key: partner.key)
  end

  test "partner user must have subscription to visit dashboard" do
    partner = Partners.default
    @user.update!(onboarded_at: 1.day.ago, partner_metadata: partner.default_metadata)

    get root_path
    assert_redirected_to trial_partner_onboarding_path(partner_key: partner.key)
  end

  test "partner without trial step skips trial redirect" do
    Partners.configure(
      "partners" => {
        "chancen" => {
          "name" => "Chancen",
          "metadata" => {
            "defaults" => { "key" => "chancen" }
          },
          "onboarding" => {
            "steps" => %w[setup preferences goals]
          }
        }
      }
    )

    partner = Partners.default
    @user.update!(
      onboarded_at: 1.day.ago,
      partner_metadata: partner.default_metadata
    )

    error = assert_raises(ActionView::Template::Error) do
      get root_path
    end

    assert_includes error.message, "tailwind.css"
  end
end
