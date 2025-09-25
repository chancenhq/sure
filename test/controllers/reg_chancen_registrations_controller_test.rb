require "test_helper"

class RegChancenRegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "welcome" do
    get welcome_reg_chancen_url
    assert_response :success
    assert_select "a", text: I18n.t("reg_chancen_registrations.welcome.cta")
  end

  test "new" do
    get new_reg_chancen_url
    assert_response :success
    assert_select "form[action='#{reg_chancen_path}']"
    assert_select "button.gsi-material-button span.gsi-material-button-contents", text: I18n.t("reg_chancen_registrations.new.google_auth_connect")
  end

  test "create sets special fields and redirects to chancen onboarding" do
    post reg_chancen_url, params: { user: {
      email: "john@example.com",
      password: "Password1!" } }

    assert_redirected_to chancen_onboarding_url
    user = User.order(created_at: :desc).first
    assert_equal "kenya", user.pei
    assert_equal "choice", user.bank
  end

  test "create when hosted requires an invite code" do
    with_env_overrides REQUIRE_INVITE_CODE: "true" do
      assert_no_difference "User.count" do
        post reg_chancen_url, params: { user: {
          email: "john@example.com",
          password: "Password1!" } }
        assert_redirected_to new_reg_chancen_url

        post reg_chancen_url, params: { user: {
          email: "john@example.com",
          password: "Password1!",
          invite_code: "foo" } }
        assert_redirected_to new_reg_chancen_url
      end

      assert_difference "User.count", +1 do
        post reg_chancen_url, params: { user: {
          email: "john@example.com",
          password: "Password1!",
          invite_code: InviteCode.generate! } }
        assert_redirected_to chancen_onboarding_url
        user = User.order(created_at: :desc).first
        assert_equal "kenya", user.pei
        assert_equal "choice", user.bank
      end
    end
  end
end
