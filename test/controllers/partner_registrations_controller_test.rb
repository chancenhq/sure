require "test_helper"

class PartnerRegistrationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @partner_key = Partners.default.key
  end

  test "welcome" do
    get welcome_partner_registration_url(partner_key: @partner_key)
    assert_response :success
    assert_select "a[href='#{privacy_partner_registration_path(partner_key: @partner_key)}']", text: I18n.t("partner_registrations.welcome.cta")
  end

  test "privacy" do
    get privacy_partner_registration_url(partner_key: @partner_key)
    assert_response :success
    assert_select "a[href='#{new_session_path(partner_key: @partner_key)}']", text: I18n.t("partner_registrations.privacy.agree_cta")
    assert_select "a[href='about:blank']", text: I18n.t("partner_registrations.privacy.learn_more_cta")
  end

  test "new" do
    get new_partner_registration_url(partner_key: @partner_key)
    assert_response :success
    assert_select "form[action='#{partner_registration_path(partner_key: @partner_key)}']"
    assert_select "button.gsi-material-button span.gsi-material-button-contents", text: I18n.t("partner_registrations.new.google_auth_connect")
  end

  test "create sets partner metadata and redirects to partner onboarding" do
    assert_difference "User.count", +1 do
      post partner_registration_url(partner_key: @partner_key), params: { user: {
        email: "john@example.com",
        password: "Password1!"
      } }
    end

    user = User.order(created_at: :desc).first
    assert_redirected_to partner_onboarding_url(partner_key: @partner_key)
    assert_equal "chancen-ke", user.partner_key
    assert_equal "KE", user.partner_metadata_value(:country)
    assert_equal [ "Choice Bank" ], user.partner_metadata_value(:bank_array)
    assert_equal "intro", user.ui_layout
    assert user.ai_enabled
  end

  test "create when hosted requires an invite code" do
    with_env_overrides REQUIRE_INVITE_CODE: "true" do
      assert_no_difference "User.count" do
        post partner_registration_url(partner_key: @partner_key), params: { user: {
          email: "john@example.com",
          password: "Password1!"
        } }
        assert_redirected_to new_partner_registration_url(partner_key: @partner_key)

        post partner_registration_url(partner_key: @partner_key), params: { user: {
          email: "john@example.com",
          password: "Password1!",
          invite_code: "foo"
        } }
        assert_redirected_to new_partner_registration_url(partner_key: @partner_key)
      end

      assert_difference "User.count", +1 do
        post partner_registration_url(partner_key: @partner_key), params: { user: {
          email: "john@example.com",
          password: "Password1!",
          invite_code: InviteCode.generate!
        } }
        user = User.order(created_at: :desc).first
        assert_redirected_to partner_onboarding_url(partner_key: @partner_key)
        assert_equal "chancen-ke", user.partner_key
        assert_equal "intro", user.ui_layout
        assert user.ai_enabled
      end
    end
  end
end
