require "application_system_test_case"

class SettingsTest < ApplicationSystemTestCase
  setup do
    sign_in @user = users(:family_admin)

    @settings_links = [
      [ "Accounts", accounts_path ],
      [ "Bank Sync", settings_bank_sync_path ],
      [ "Preferences", settings_preferences_path ],
      [ "Profile Info", settings_profile_path ],
      [ "Security", settings_security_path ],
      [ "Categories", categories_path ],
      [ "Tags", tags_path ],
      [ "Rules", rules_path ],
      [ "Merchants", family_merchants_path ],
      [ "AI Prompts", settings_ai_prompts_path ],
      [ "API Key", settings_api_key_path ],
      [ "Guides", settings_guides_path ],
      [ "What's new", changelog_path ],
      [ "Feedback", feedback_path ]
    ]
  end

  test "can access settings from sidebar" do
    VCR.use_cassette("git_repository_provider/fetch_latest_release_notes") do
      open_settings_from_sidebar
      assert_selector "h1", text: "Accounts"
      assert_current_path accounts_path, ignore_query: true

      @settings_links.each do |name, path|
        click_link name
        assert_selector "h1", text: name
        assert_current_path path
      end
    end
  end

  test "can update self hosting settings" do
    Rails.application.config.app_mode.stubs(:self_hosted?).returns(true)
    Provider::Registry.stubs(:get_provider).with(:twelve_data).returns(nil)
    open_settings_from_sidebar
    assert_selector "li", text: "Self-Hosting"
    click_link "Self-Hosting"
    assert_current_path settings_hosting_path
    assert_selector "h1", text: "Self-Hosting"
    check "setting[require_invite_for_signup]", allow_label_click: true
    click_button "Generate new code"
    assert_selector 'span[data-clipboard-target="source"]', visible: true, count: 1 # invite code copy widget
    copy_button = find('button[data-action="clipboard#copy"]', match: :first) # Find the first copy button (adjust if needed)
    copy_button.click
    assert_selector 'span[data-clipboard-target="iconSuccess"]', visible: true, count: 1 # text copied and icon changed to checkmark
  end

  test "can update AI system prompt" do
    begin
      Setting.assistant_system_prompt_template = nil

      open_settings_from_sidebar
      click_link "AI Prompts"
      find("summary", text: I18n.t("settings.ai_prompts.show.prompt_instructions"), match: :first).click
      assert_current_path settings_ai_prompts_path

      new_prompt = "You are helpful. Today is {{current_date}}."
      fill_in "setting_assistant_system_prompt_template", with: new_prompt
      click_button "Save prompt"

      assert_text "System prompt updated successfully."
      assert_equal new_prompt, Setting.assistant_system_prompt_template

      within "[data-testid=system-prompt-preview]" do
        assert_text Date.current.to_s
      end
    ensure
      Setting.assistant_system_prompt_template = nil
    end
  end

  test "does not show billing link if self hosting" do
    Rails.application.config.app_mode.stubs(:self_hosted?).returns(true)
    open_settings_from_sidebar
    assert_no_selector "li", text: I18n.t("settings.settings_nav.billing_label")
  end

  private

    def open_settings_from_sidebar
      within "div[data-testid=user-menu]" do
        find("button").click
      end
      click_link "Settings"
    end
end
