require "test_helper"

class MessagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in @user = users(:family_admin)
    @chat = @user.chats.first
  end

  test "can create a message" do
    post chat_messages_url(@chat), params: { message: { content: "Hello", ai_model: "gpt-4.1" } }

    assert_redirected_to chat_path(@chat, thinking: true)
  end

  test "can create a message with a custom system prompt" do
    begin
      Setting.assistant_system_prompt_template = <<~PROMPT
        Be concise and helpful.

        Use currency {{preferred_currency_symbol}} and date {{current_date}}.
      PROMPT

      post chat_messages_url(@chat), params: { message: { content: "Hi", ai_model: "gpt-4.1" } }

      assert_redirected_to chat_path(@chat, thinking: true)
    ensure
      Setting.assistant_system_prompt_template = nil
    end
  end

  test "can create a message after updating system prompt through settings" do
    begin
      patch settings_ai_prompts_path, params: { setting: { assistant_system_prompt_template: "Follow context {{preferred_date_format}}" } }

      post chat_messages_url(@chat), params: { message: { content: "Question", ai_model: "gpt-4.1" } }

      assert_redirected_to chat_path(@chat, thinking: true)
      assert_equal "Follow context {{preferred_date_format}}", Setting.assistant_system_prompt_template
    ensure
      Setting.assistant_system_prompt_template = nil
    end
  end

  test "does not create a message when content is blank" do
    assert_no_difference("Message.count") do
      post chat_messages_url(@chat), params: { message: { content: "   ", ai_model: "gpt-4.1" } }
    end

    assert_redirected_to chat_path(@chat)
    assert_equal I18n.t("messages.create.blank_content"), flash[:alert]
  end

  test "cannot create a message if AI is disabled" do
    @user.update!(ai_enabled: false)

    post chat_messages_url(@chat), params: { message: { content: "Hello", ai_model: "gpt-4.1" } }

    assert_response :forbidden
  end
end
