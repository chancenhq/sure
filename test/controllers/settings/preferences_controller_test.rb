require "test_helper"

class Settings::PreferencesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:family_admin)
  end
  test "get" do
    get settings_preferences_url
    assert_response :success
  end

  test "intro users redirect to profile" do
    user = users(:family_admin)
    user.update!(ui_layout: :intro)
    sign_in user

    get settings_preferences_url

    assert_redirected_to settings_profile_url
  end
end
