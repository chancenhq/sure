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

    assert_equal %i[setup preferences goals trial], steps.map { |step| step[:key] }
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
end
