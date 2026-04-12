require "test_helper"

class Settings::AiPromptsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:family_admin)
  end

  test "updates langfuse prompt cache ttl setting" do
    original_ttl = Setting.langfuse_prompt_cache_ttl_seconds

    patch settings_ai_prompts_url, params: { setting: { langfuse_prompt_cache_ttl_seconds: 604_800 } }

    assert_redirected_to settings_ai_prompts_url
    assert_equal 604_800, Setting.langfuse_prompt_cache_ttl_seconds
  ensure
    Setting.langfuse_prompt_cache_ttl_seconds = original_ttl
  end
end
