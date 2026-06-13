require 'digest'

# Generate a GUID
guid = "RU-yyxyx-xyyx-4xyx-yxyx-yy-xx-yx"
guid = guid.gsub('x') { rand(16).to_s(16) }
           .gsub('y') { rand(4).to_s(16) }

puts "Generated GUID: #{guid}"

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
  flat_entries = flatten_object(obj).reject { |_, v| v.nil? }
  flat_entries.sort_by! { |k, _| k.downcase }
  flat_entries.map { |k, v| "#{k}=#{v}" }.join("&")
end

# Prepare request body (sign and return)
def prepare_request_body(request_body)
  flat_string = object_to_query_string(request_body)
  puts "Flattened: #{flat_string}"

  signature = Digest::SHA256.hexdigest(flat_string)
  puts "Signature: #{signature}"

  request_body[:signature] = signature
  request_body.delete(:senderKey)
  request_body
end

# Example usage:
request = {
  name: "Tester",
  senderKey: "secret",
  meta: {
    age: 30,
    country: "KE"
  }
}

signed_request = prepare_request_body(request)
puts signed_request
