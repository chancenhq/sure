# ChoiceBank Webhook Integration

This document describes how to integrate with the `choice` webhook endpoint that validates requests using the agreed upon signature generation algorithm.

## Endpoint

```
POST /webhooks/choice
```

## Authentication

The webhook uses signature-based authentication. The signature is included in the request body and validated using the SHA256 algorithm.

## Request Format

### Headers
- `Content-Type: application/json`
- `X-Choice-Signature: <signature>` (optional, for additional verification)

### Body Format

```json
{
  "id": "webhook_123",
  "type": "user.created",
  "data": {
    "user_id": "user_456",
    "email": "test@example.com",
    "name": "Test User"
  },
  "signature": "generated_signature_here"
}
```

## Signature Generation

The signature is generated using the following algorithm:

1. **Flatten the object**: Convert nested objects and arrays into a flat key-value structure
2. **Sort keys alphabetically**: Sort all keys in case-insensitive alphabetical order
3. **Build query string**: Convert to `key=value&key2=value2` format
4. **Generate SHA256 hash**: Create a SHA256 hash of the query string

### Example

```ruby
# Original object
{
  "name": "Tester",
  "meta": {
    "age": 30,
    "country": "KE"
  }
}

# Flattened and sorted
"age=30&country=KE&name=Tester"

# SHA256 hash
signature = Digest::SHA256.hexdigest("age=30&country=KE&name=Tester")
```

### Nested Objects

Nested objects are flattened using dot notation:

```ruby
{
  "user": {
    "profile": {
      "name": "John"
    }
  }
}

# Becomes
"user.profile.name=John"
```

### Arrays

Arrays are flattened using bracket notation:

```ruby
{
  "items": [
    {"id": 1, "name": "Item 1"},
    {"id": 2, "name": "Item 2"}
  ]
}

# Becomes
"items[0].id=1&items[0].name=Item 1&items[1].id=2&items[1].name=Item 2"
```

## Supported Event Types

The webhook processor handles the following event types:

- `user.created` - When a new user is created
- `user.updated` - When a user is updated
- `payment.completed` - When a payment is completed
- `subscription.cancelled` - When a subscription is cancelled

Unknown event types are logged but don't cause errors.

## Response Format

### Success Response

```json
{
  "received": true
}
```

### Error Responses

#### Invalid JSON
```json
{
  "error": "Invalid JSON"
}
```

#### Invalid Signature
```json
{
  "error": "Invalid signature"
}
```

#### Processing Error
```json
{
  "error": "Webhook processing failed"
}
```

## Configuration

The webhook secret is configured via environment variable or Rails credentials:

```ruby
# Environment variable
ENV["CHOICE_WEBHOOK_SECRET"]

# Or Rails credentials
Rails.application.credentials.choice_webhook_secret
```

## Testing

You can test the webhook using the provided test cases in `test/controllers/webhooks_controller_test.rb` and `test/services/signature_validator_test.rb`.

## Security Considerations

1. **Signature Validation**: Always validate the signature to ensure the request is authentic
2. **HTTPS**: Use HTTPS in production to encrypt webhook payloads
3. **Idempotency**: Webhook handlers should be idempotent to handle duplicate deliveries
4. **Error Handling**: Always return a 200 status code to prevent webhook retries
5. **Logging**: All webhook events are logged and errors are reported to Sentry

## Example Integration

```ruby
require 'net/http'
require 'json'
require 'digest'

def send_webhook(event_type, data)
  payload = {
    "id" => "webhook_#{Time.current.to_i}",
    "type" => event_type,
    "data" => data
  }
  
  # Generate signature
  flat_string = flatten_and_sort(payload)
  signature = Digest::SHA256.hexdigest(flat_string)
  payload["signature"] = signature
  
  # Send request
  uri = URI('https://your-app.com/webhooks/choice')
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  
  request = Net::HTTP::Post.new(uri)
  request['Content-Type'] = 'application/json'
  request.body = payload.to_json
  
  response = http.request(request)
  puts "Webhook sent: #{response.code}"
end

# Usage
send_webhook("user.created", {
  "user_id" => "user_123",
  "email" => "user@example.com"
})
``` 