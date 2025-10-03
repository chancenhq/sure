require "test_helper"

class PartnerOnboardingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    Partners.reset!

    @user = users(:family_admin)
    @family = @user.family
    @partner = configure_partner(%w[setup preferences goals trial])

    @user.update!(
      set_onboarding_preferences_at: nil,
      partner_metadata: @partner.default_metadata
    )

    sign_in @user
  end

  teardown do
    Partners.reset!
  end

  test "should get show" do
    get partner_onboarding_url(partner_key: @partner.key)
    assert_response :success
    assert_select "h1", text: /set up your account/i
  end

  test "should get preferences" do
    get preferences_partner_onboarding_url(partner_key: @partner.key)
    assert_response :success
    assert_select "h1", text: /configure your preferences/i
  end

  test "preferences page renders Series chart data without errors" do
    get preferences_partner_onboarding_url(partner_key: @partner.key)
    assert_response :success

    assert_select "[data-controller='time-series-chart']"
    assert_select "#previewChart"
    assert_no_match /unknown keyword: :trend/, response.body
  end

  test "preferences page includes chart with valid JSON data" do
    get preferences_partner_onboarding_url(partner_key: @partner.key)
    assert_response :success

    chart_data_match = response.body.match(/data-time-series-chart-data-value=\"([^\"]*)\"/)
    assert chart_data_match, "Chart data attribute should be present"

    chart_data_json = CGI.unescapeHTML(chart_data_match[1])

    assert_nothing_raised do
      chart_data = JSON.parse(chart_data_json)

      assert chart_data.key?("start_date")
      assert chart_data.key?("end_date")
      assert chart_data.key?("interval")
      assert chart_data.key?("trend")
      assert chart_data.key?("values")

      trend = chart_data["trend"]
      assert trend.key?("value")
      assert trend.key?("percent")
      assert trend.key?("current")
      assert trend.key?("previous")

      values = chart_data["values"]
      assert values.is_a?(Array)
      assert values.length.positive?

      values.each do |value|
        assert value.key?("date")
        assert value.key?("value")
        assert value.key?("trend")
      end
    end
  end

  test "should get goals" do
    get goals_partner_onboarding_url(partner_key: @partner.key)
    assert_response :success
    assert_select "h1", text: /What brings you to/i
  end

  test "should get trial" do
    get trial_partner_onboarding_url(partner_key: @partner.key)
    assert_response :success
  end

  test "trial step is optional when not configured" do
    @partner = configure_partner(%w[setup preferences goals])
    @user.update!(partner_metadata: @partner.default_metadata)

    get trial_partner_onboarding_url(partner_key: @partner.key)
    assert_response :not_found
  end

  test "navigation hides steps that are not configured" do
    @partner = configure_partner(%w[setup preferences goals])
    @user.update!(partner_metadata: @partner.default_metadata)

    get partner_onboarding_url(partner_key: @partner.key)
    assert_response :success
    assert_select "ul li", text: /Setup/
    assert_select "ul li", text: /Preferences/
    assert_select "ul li", text: /Goals/
    assert_select "ul li", text: /Start/, count: 0
  end

  test "preferences page shows currency formatting example" do
    get preferences_partner_onboarding_url(partner_key: @partner.key)
    assert_response :success

    assert_select "p", text: /\$2,325\.25/
    assert_select "span", text: /\+\$78\.90/
  end

  test "preferences page shows date formatting example" do
    get preferences_partner_onboarding_url(partner_key: @partner.key)
    assert_response :success

    assert_match /2024/, response.body
  end

  test "preferences page includes all required form fields" do
    get preferences_partner_onboarding_url(partner_key: @partner.key)
    assert_response :success

    assert_select "select[name='user[family_attributes][locale]']"
    assert_select "select[name='user[family_attributes][currency]']"
    assert_select "select[name='user[family_attributes][date_format]']"
    assert_select "select[name='user[theme]']"
    assert_select "button[type='submit']"
  end

  test "preferences page includes JavaScript controllers" do
    get preferences_partner_onboarding_url(partner_key: @partner.key)
    assert_response :success

    assert_select "[data-controller*='onboarding']"
    assert_select "[data-controller*='time-series-chart']"
  end

  test "all onboarding pages set correct layout" do
    get partner_onboarding_url(partner_key: @partner.key)
    assert_response :success

    get preferences_partner_onboarding_url(partner_key: @partner.key)
    assert_response :success

    get goals_partner_onboarding_url(partner_key: @partner.key)
    assert_response :success

    get trial_partner_onboarding_url(partner_key: @partner.key)
    assert_response :success
  end

  test "onboarding pages require authentication" do
    sign_out_user

    get partner_onboarding_url(partner_key: @partner.key)
    assert_redirected_to new_session_url

    get preferences_partner_onboarding_url(partner_key: @partner.key)
    assert_redirected_to new_session_url

    get goals_partner_onboarding_url(partner_key: @partner.key)
    assert_redirected_to new_session_url

    get trial_partner_onboarding_url(partner_key: @partner.key)
    assert_redirected_to new_session_url
  end

  private

    def configure_partner(steps)
      Partners.configure(
        "partners" => {
          "chancen" => {
            "name" => "Chancen",
            "type" => "education",
            "metadata" => {
              "required" => %w[key name pei bank type],
              "defaults" => {
                "key" => "chancen",
                "name" => "Chancen",
                "pei" => "kenya",
                "bank" => "choice",
                "type" => "education"
              }
            },
            "onboarding" => {
              "steps" => steps
            }
          }
        }
      )

      Partners.default
    end

    def sign_out_user
      @user.sessions.each do |session|
        delete session_path(session)
      end
    end
end
