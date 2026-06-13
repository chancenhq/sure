require "test_helper"

class WebhooksControllerTest < ActionDispatch::IntegrationTest
  test "plaid webhook" do
    # Test implementation for Plaid webhook
  end

  test "plaid_eu webhook" do
    # Test implementation for Plaid EU webhook
  end

  test "stripe webhook" do
    # Test implementation for Stripe webhook
  end

  test "choice webhook with valid signature" do
    # Create a valid webhook payload
    webhook_data = {
      "id" => "webhook_123",
      "type" => "user.created",
      "data" => {
        "user_id" => "user_456",
        "email" => "test@example.com",
        "name" => "Test User"
      }
    }

    # Generate the signature using the same algorithm
    flat_string = "data.email=test@example.com&data.name=Test User&data.user_id=user_456&id=webhook_123&type=user.created"
    signature = Digest::SHA256.hexdigest(flat_string)
    webhook_data["signature"] = signature

    post webhooks_choice_url, params: webhook_data.to_json, headers: {
      "Content-Type" => "application/json",
      "X-Choice-Signature" => signature
    }

    assert_response :success
    assert_equal({ "received" => true }, JSON.parse(response.body))
  end

  test "choice webhook with invalid signature" do
    webhook_data = {
      "id" => "webhook_123",
      "type" => "user.created",
      "data" => {
        "user_id" => "user_456",
        "email" => "test@example.com"
      },
      "signature" => "invalid_signature"
    }

    post webhooks_choice_url, params: webhook_data.to_json, headers: {
      "Content-Type" => "application/json"
    }

    assert_response :unauthorized
    assert_equal({ "error" => "Invalid signature" }, JSON.parse(response.body))
  end

  test "choice webhook with invalid JSON" do
    post webhooks_choice_url, params: "invalid json", headers: {
      "Content-Type" => "application/json"
    }

    assert_response :bad_request
    assert_equal({ "error" => "Invalid JSON" }, JSON.parse(response.body))
  end

  test "choice webhook processes different event types" do
    event_types = ["user.created", "user.updated", "payment.completed", "subscription.cancelled"]

    event_types.each do |event_type|
      webhook_data = {
        "id" => "webhook_#{event_type}",
        "type" => event_type,
        "data" => {
          "test" => "data"
        }
      }

      # Generate signature
      flat_string = "data.test=data&id=webhook_#{event_type}&type=#{event_type}"
      signature = Digest::SHA256.hexdigest(flat_string)
      webhook_data["signature"] = signature

      post webhooks_choice_url, params: webhook_data.to_json, headers: {
        "Content-Type" => "application/json"
      }

      assert_response :success, "Failed for event type: #{event_type}"
    end
  end

  test "choice webhook handles unknown event type" do
    webhook_data = {
      "id" => "webhook_unknown",
      "type" => "unknown.event",
      "data" => {
        "test" => "data"
      }
    }

    # Generate signature
    flat_string = "data.test=data&id=webhook_unknown&type=unknown.event"
    signature = Digest::SHA256.hexdigest(flat_string)
    webhook_data["signature"] = signature

    post webhooks_choice_url, params: webhook_data.to_json, headers: {
      "Content-Type" => "application/json"
    }

    # Should still return 200 even for unknown event types
    assert_response :success
    assert_equal({ "received" => true }, JSON.parse(response.body))
  end
end
