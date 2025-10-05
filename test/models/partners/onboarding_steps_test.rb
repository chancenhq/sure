require "test_helper"

class Partners::OnboardingStepsTest < ActiveSupport::TestCase
  setup do
    Partners.reset!
    @partner = Partners.default
    @user = users(:family_admin)
    @controller = ApplicationController.new
    @controller.request = ActionDispatch::TestRequest.create
    @view = ActionView::Base.new(ActionController::Base.view_paths, {}, @controller)
    @view.extend Rails.application.routes.url_helpers
    @view.singleton_class.send(:define_method, :url_options) { {} }
  end

  teardown do
    Partners.reset!
  end

  test "build_steps returns configured steps" do
    steps = Partners::OnboardingSteps.build_steps(
      partner: @partner,
      user: @user,
      view_context: @view,
      route_params: { partner_key: @partner.key }
    )

    expected_keys = Partners::OnboardingSteps.enabled_keys(@partner).map(&:to_sym)
    assert_equal expected_keys, steps.map { |step| step[:key] }
    assert steps.all? { |step| step[:name].present? }
  end

  test "enabled_keys falls back to defaults when configuration missing" do
    partner = Partners::Definition.new("custom", {})
    assert_equal %w[setup preferences goals trial], Partners::OnboardingSteps.enabled_keys(partner)
  end

  test "include? respects partner configuration" do
    Partners.configure(
      "partners" => {
        "custom" => {
          "name" => "Custom",
          "metadata" => {
            "defaults" => {}
          },
          "onboarding" => {
            "steps" => %w[setup goals]
          }
        }
      }
    )

    partner = Partners.find(:custom)

    assert Partners::OnboardingSteps.include?(partner, :setup)
    assert_not Partners::OnboardingSteps.include?(partner, :preferences)
    assert Partners::OnboardingSteps.include?(partner, :goals)
    assert_not Partners::OnboardingSteps.include?(partner, :trial)
  end

  test "auto completes skipped setup and preferences using defaults" do
    Partners.configure(
      "partners" => {
        "streamlined" => {
          "name" => "Streamlined",
          "metadata" => {
            "defaults" => {
              "key" => "streamlined",
              "currency" => "CAD",
              "locale" => "fr",
              "country" => "ca",
              "date_format" => "%d/%m/%Y"
            }
          },
          "onboarding" => {
            "steps" => %w[goals]
          }
        }
      }
    )

    partner = Partners.default
    @user.family.update!(locale: "en", currency: "USD", date_format: "%m-%d-%Y", country: "US")
    @user.update!(
      first_name: nil,
      last_name: nil,
      theme: nil,
      set_onboarding_preferences_at: nil,
      partner_metadata: partner.default_metadata
    )

    travel_to Time.current do
      Partners::OnboardingSteps.auto_complete_missing_steps!(partner: partner, user: @user)
    end

    @user.reload
    family = @user.family.reload

    assert @user.first_name.present?
    assert_nil @user.last_name
    assert_equal "system", @user.theme
    assert_not_nil @user.set_onboarding_preferences_at
    assert_equal "fr", family.locale
    assert_equal "CAD", family.currency
    assert_equal "%d/%m/%Y", family.date_format
    assert_equal "ca", family.country
  end

  test "auto complete preferences falls back to default values when partner missing metadata" do
    Partners.configure(
      "partners" => {
        "lean" => {
          "name" => "Lean",
          "metadata" => {
            "defaults" => { "key" => "lean" }
          },
          "onboarding" => {
            "steps" => %w[goals]
          }
        }
      }
    )

    partner = Partners.default
    @user.family.update!(locale: "en", currency: "CAD", date_format: "%d/%m/%Y", country: "CA")
    @user.update!(
      first_name: nil,
      theme: nil,
      set_onboarding_preferences_at: nil,
      partner_metadata: partner.default_metadata
    )

    travel_to Time.current do
      Partners::OnboardingSteps.auto_complete_missing_steps!(partner: partner, user: @user)
    end

    family = @user.family.reload

    assert_equal "en", family.locale
    assert_equal "USD", family.currency
    assert_equal "%Y-%m-%d", family.date_format
    assert_equal "US", family.country
  end
end
