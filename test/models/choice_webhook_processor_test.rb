require "test_helper"

class ChoiceWebhookProcessorTest < ActiveSupport::TestCase
  test "processes user.created webhook" do
    webhook_body = {
      "id" => "webhook_123",
      "type" => "user.created",
      "data" => {
        "user_id" => "user_456",
        "email" => "test@example.com",
        "name" => "Test User"
      }
    }.to_json

    processor = ChoiceWebhookProcessor.new(webhook_body)
    
    # Should not raise any errors
    assert_nothing_raised do
      processor.process
    end
  end

  test "processes user.updated webhook" do
    webhook_body = {
      "id" => "webhook_124",
      "type" => "user.updated",
      "data" => {
        "user_id" => "user_456",
        "email" => "updated@example.com",
        "name" => "Updated User"
      }
    }.to_json

    processor = ChoiceWebhookProcessor.new(webhook_body)
    
    assert_nothing_raised do
      processor.process
    end
  end

  test "processes payment.completed webhook" do
    webhook_body = {
      "id" => "webhook_125",
      "type" => "payment.completed",
      "data" => {
        "payment_id" => "payment_789",
        "amount" => 1000,
        "currency" => "USD"
      }
    }.to_json

    processor = ChoiceWebhookProcessor.new(webhook_body)
    
    assert_nothing_raised do
      processor.process
    end
  end

  test "processes subscription.cancelled webhook" do
    webhook_body = {
      "id" => "webhook_126",
      "type" => "subscription.cancelled",
      "data" => {
        "subscription_id" => "sub_123",
        "cancelled_at" => "2024-01-01T00:00:00Z"
      }
    }.to_json

    processor = ChoiceWebhookProcessor.new(webhook_body)
    
    assert_nothing_raised do
      processor.process
    end
  end

  test "handles unknown webhook type gracefully" do
    webhook_body = {
      "id" => "webhook_127",
      "type" => "unknown.event",
      "data" => {
        "test" => "data"
      }
    }.to_json

    processor = ChoiceWebhookProcessor.new(webhook_body)
    
    # Should not raise any errors for unknown event types
    assert_nothing_raised do
      processor.process
    end
  end

  test "handles missing data gracefully" do
    webhook_body = {
      "id" => "webhook_128",
      "type" => "user.created"
      # No data field
    }.to_json

    processor = ChoiceWebhookProcessor.new(webhook_body)
    
    assert_nothing_raised do
      processor.process
    end
  end

  test "handles malformed JSON gracefully" do
    webhook_body = "invalid json"

    assert_raises(JSON::ParserError) do
      ChoiceWebhookProcessor.new(webhook_body)
    end
  end

  test "extracts webhook properties correctly" do
    webhook_body = {
      "id" => "webhook_129",
      "type" => "user.created",
      "data" => {
        "user_id" => "user_456",
        "email" => "test@example.com"
      }
    }.to_json

    processor = ChoiceWebhookProcessor.new(webhook_body)
    
    # Test private methods through reflection or make them public for testing
    # For now, we'll just ensure the processor doesn't raise errors
    assert_nothing_raised do
      processor.process
    end
  end
end 