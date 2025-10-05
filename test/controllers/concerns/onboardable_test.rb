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
    assert_redirected_to dashboard_path

    follow_redirect!
    assert_response :success
  end

  test "partner user must complete partner onboarding before any other action" do
    partner = Partners.default
    @user.update!(onboarded_at: nil, partner_metadata: partner.default_metadata)

    get root_path
    assert_redirected_to goals_partner_onboarding_path(partner_key: partner.key)
  end

  test "partner user must have subscription to visit dashboard" do
    partner = Partners.default
    @user.update!(onboarded_at: 1.day.ago, partner_metadata: partner.default_metadata)

    get root_path
    assert_redirected_to dashboard_path
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

    get root_path

    assert_redirected_to dashboard_path
  end

  test "skipped setup and preferences auto complete and redirect to goals" do
    Partners.configure(
      "partners" => {
        "streamlined" => {
          "name" => "Streamlined",
          "metadata" => {
            "defaults" => { "key" => "streamlined" }
          },
          "onboarding" => {
            "steps" => %w[goals trial]
          }
        }
      }
    )

    partner = Partners.default
    @user.update!(
      onboarded_at: nil,
      first_name: nil,
      set_onboarding_preferences_at: nil,
      partner_metadata: partner.default_metadata
    )

    travel_to Time.current do
      get root_path
    end

    assert_redirected_to goals_partner_onboarding_path(partner_key: partner.key)

    @user.reload
    assert @user.first_name.present?
    assert_not_nil @user.set_onboarding_preferences_at
    assert_nil @user.set_onboarding_goals_at
  end
end
