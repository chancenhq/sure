require 'json'
require 'digest'

# Get host from command line argument or default to localhost:3000
HOST = ARGV[0] || "http://localhost:3000"

# Show usage if help is requested
if ARGV.include?('--help') || ARGV.include?('-h')
  puts "Usage: ruby test_choice_webhook.rb [HOST]"
  puts "  HOST: The base URL of your Rails app (default: http://localhost:3000)"
  puts ""
  puts "Examples:"
  puts "  ruby test_choice_webhook.rb                                    # Use localhost:3000"
  puts "  ruby test_choice_webhook.rb https://myapp.com                  # Use production URL"
  puts "  ruby test_choice_webhook.rb http://staging.example.com         # Use staging URL"
  exit
end

# Test secret key (you can change this)
SECRET_KEY = "test_secret_key_123"

# Flatten nested objects (hashes/arrays)
def flatten_object(obj, path = [])
  return [[path.join, obj]] unless obj.is_a?(Hash) || obj.is_a?(Array)

  flat_entries = []
  obj.each_with_index do |(key, value), index|
    new_key = if obj.is_a?(Array)
                "#{path.join}[#{index}]"
              else
                path.empty? ? key.to_s : "#{path.join}.#{key}"
              end
    flat_entries += flatten_object(value, [new_key])
  end
  flat_entries
end

# Build query string from flattened hash
def object_to_query_string(obj)
  # Remove the signature field if present for validation
  obj_without_signature = obj.reject { |k, _| k == 'signature' || k == :signature }
  
  flat_entries = flatten_object(obj_without_signature).reject { |_, v| v.nil? }
  flat_entries.sort_by! { |k, _| k.downcase }
  flat_entries.map { |k, v| "#{k}=#{v}" }.join("&")
end

def generate_signature(request_body)
  flat_string = object_to_query_string(request_body)
  Digest::SHA256.hexdigest(flat_string)
end

# Create test webhook payload
webhook_data1 = {
  "id" => "webhook_#{Time.now.to_i}",
  "type" => "user.created",
  "data" => {
    "user_id" => "user_456",
    "email" => "test@example.com",
    "name" => "Test User"
  }
}
# Example usage:
webhook_data2 = {
  name: "Tester",
  senderKey: "secret",
  meta: {
    age: 30,
    country: "KE"
  }
}

# Java sample jsonStr
webhook_data3 = {
  code: "00000",
  msg: "Completed successfully",
  requestId: "APPREQ00990320fed02000",
  sender: "choice.baas",
  locale: "en_KE",
  timestamp: 1650533105687,
  salt: "QcEwsZHMUr",
  signature: "cdfd996e7e5ca655d3fa663db03abe63b852669f04e1f82fda9b473f606a11",
  data: {
    accountId: "46012123456789"
  }
}

webhook_data = webhook_data3

# Generate signature
signature = generate_signature(webhook_data)
webhook_data["signature"] = signature

puts "=== Choice Webhook Test ==="
puts "Host: #{HOST}"
puts "Secret Key: #{SECRET_KEY}"
puts "Generated Signature: #{signature}"
puts "Flattened String: #{object_to_query_string(webhook_data.reject { |k, _| k == 'signature' })}"
puts

puts "=== cURL Command ==="
puts "curl -X POST #{HOST}/webhooks/choice \\"
puts "  -H 'Content-Type: application/json' \\"
puts "  -H 'X-Choice-Signature: #{signature}' \\"
puts "  -d '#{webhook_data.to_json}'"
puts

puts "=== Alternative cURL (without header) ==="
puts "curl -X POST #{HOST}/webhooks/choice \\"
puts "  -H 'Content-Type: application/json' \\"
puts "  -d '#{webhook_data.to_json}'"
puts

puts "=== Test Different Event Types ==="

event_types = ["test-hook-1", "test-hook-2", "user.created", "user.updated", "payment.completed", "subscription.cancelled"]

event_types.each do |event_type|
  test_data = {
    "id" => "webhook_#{event_type}",
    "type" => event_type,
    "data" => {
      "test" => "data",
      "timestamp" => Time.now.to_i
    }
  }
  
  test_signature = generate_signature(test_data)
  test_data["signature"] = test_signature
  
  puts "Event: #{event_type}"
  puts "Signature: #{test_signature}"
  puts "cURL: curl -X POST #{HOST}/webhooks/choice -H 'Content-Type: application/json' -d '#{test_data.to_json}'"
  puts
end 