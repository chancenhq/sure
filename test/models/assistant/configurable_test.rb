require "test_helper"

class AssistantConfigurableTest < ActiveSupport::TestCase
  setup { reset_langfuse_client_cache }
  teardown { reset_langfuse_client_cache }

  test "returns dashboard configuration by default" do
    chat = chats(:one)

    config = Assistant.config_for(chat)

    assert_not_empty config[:functions]
    assert_includes config[:instructions], "You help users understand their financial data"
    assert_nil config[:prompt_name]
    assert_nil config[:prompt_version]
  end

  test "returns intro configuration without functions" do
    chat = chats(:intro)

    config = Assistant.config_for(chat)

    assert_equal [], config[:functions]
    assert_includes config[:instructions], "stage of life"
    assert_nil config[:prompt_name]
    assert_nil config[:prompt_version]
  end

  test "uses Langfuse default_instructions prompt when available" do
    chat = chats(:one)
    fake_prompt = Struct.new(:version) do
      def compile(_variables)
        "Prompt from Langfuse"
      end
    end.new(12)
    fake_client = mock

    original_public_key = ENV["LANGFUSE_PUBLIC_KEY"]
    original_secret_key = ENV["LANGFUSE_SECRET_KEY"]
    original_prompt_ttl = Setting.langfuse_prompt_cache_ttl_seconds
    ENV["LANGFUSE_PUBLIC_KEY"] = "pk-test"
    ENV["LANGFUSE_SECRET_KEY"] = "sk-test"
    Setting.langfuse_prompt_cache_ttl_seconds = 60

    begin
      Langfuse.expects(:new).returns(fake_client)
      fake_client.expects(:get_prompt).with("default_instructions", cache_ttl_seconds: 60).returns(fake_prompt)

      config = Assistant.config_for(chat)

      assert_equal "Prompt from Langfuse", config[:instructions]
      assert_equal "default_instructions", config[:prompt_name]
      assert_equal 12, config[:prompt_version]
    ensure
      ENV["LANGFUSE_PUBLIC_KEY"] = original_public_key
      ENV["LANGFUSE_SECRET_KEY"] = original_secret_key
      Setting.langfuse_prompt_cache_ttl_seconds = original_prompt_ttl
    end
  end

  test "memoizes Langfuse client so prompt caching can work across requests" do
    chat = chats(:one)
    fake_prompt = Struct.new(:version) do
      def compile(_variables)
        "Prompt from Langfuse"
      end
    end.new(1)
    fake_client = mock

    original_public_key = ENV["LANGFUSE_PUBLIC_KEY"]
    original_secret_key = ENV["LANGFUSE_SECRET_KEY"]
    original_prompt_ttl = Setting.langfuse_prompt_cache_ttl_seconds
    ENV["LANGFUSE_PUBLIC_KEY"] = "pk-test"
    ENV["LANGFUSE_SECRET_KEY"] = "sk-test"
    Setting.langfuse_prompt_cache_ttl_seconds = 60

    begin
      Langfuse.expects(:new).once.returns(fake_client)
      fake_client.expects(:get_prompt).with("default_instructions", cache_ttl_seconds: 60).twice.returns(fake_prompt)

      Assistant.config_for(chat)
      Assistant.config_for(chat)
    ensure
      ENV["LANGFUSE_PUBLIC_KEY"] = original_public_key
      ENV["LANGFUSE_SECRET_KEY"] = original_secret_key
      Setting.langfuse_prompt_cache_ttl_seconds = original_prompt_ttl
    end
  end

  test "can force immediate prompt refresh by setting prompt cache ttl to zero" do
    chat = chats(:one)
    fake_prompt_v1 = Struct.new(:version) do
      def compile(_variables)
        "Prompt v1"
      end
    end.new(1)
    fake_prompt_v2 = Struct.new(:version) do
      def compile(_variables)
        "Prompt v2"
      end
    end.new(2)
    fake_client = mock

    original_public_key = ENV["LANGFUSE_PUBLIC_KEY"]
    original_secret_key = ENV["LANGFUSE_SECRET_KEY"]
    original_prompt_ttl = Setting.langfuse_prompt_cache_ttl_seconds
    ENV["LANGFUSE_PUBLIC_KEY"] = "pk-test"
    ENV["LANGFUSE_SECRET_KEY"] = "sk-test"
    Setting.langfuse_prompt_cache_ttl_seconds = 0

    begin
      Langfuse.expects(:new).once.returns(fake_client)
      fake_client.expects(:get_prompt).with("default_instructions", cache_ttl_seconds: 0).twice.returns(fake_prompt_v1, fake_prompt_v2)

      first_config = Assistant.config_for(chat)
      second_config = Assistant.config_for(chat)

      assert_equal "Prompt v1", first_config[:instructions]
      assert_equal 1, first_config[:prompt_version]
      assert_equal "Prompt v2", second_config[:instructions]
      assert_equal 2, second_config[:prompt_version]
    ensure
      ENV["LANGFUSE_PUBLIC_KEY"] = original_public_key
      ENV["LANGFUSE_SECRET_KEY"] = original_secret_key
      Setting.langfuse_prompt_cache_ttl_seconds = original_prompt_ttl
    end
  end

  private
    def reset_langfuse_client_cache
      return unless Assistant::Builtin.instance_variable_defined?(:@langfuse_client)

      Assistant::Builtin.remove_instance_variable(:@langfuse_client)
    end
end
