require "application_system_test_case"

class Settings::AiPromptsTest < ApplicationSystemTestCase
  setup do
    @user = users(:family_admin)
    @user.update!(ai_enabled: true)
    login_as @user
  end

  test "user can disable ai assistant" do
    visit settings_ai_prompts_path

    click_button "Disable AI Assistant"

    sleep 5

    assert_current_path settings_ai_prompts_path
    @user.reload
    assert_not @user.ai_enabled?
  end

  test "user can update langfuse prompt cache ttl" do
    visit settings_ai_prompts_path

    select "1 week", from: "setting_langfuse_prompt_cache_ttl_seconds"
    click_button "Save cache setting"

    assert_current_path settings_ai_prompts_path
    assert_equal 604_800, Setting.langfuse_prompt_cache_ttl_seconds
  ensure
    Setting.langfuse_prompt_cache_ttl_seconds = -1
  end
end
