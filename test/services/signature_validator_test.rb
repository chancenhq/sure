require "test_helper"

class SignatureValidatorTest < ActiveSupport::TestCase
  setup do
    @validator = SignatureValidator.new("test_secret")
  end

  test "validates correct signature" do
    request_body = {
      "name" => "Tester",
      "meta" => {
        "age" => 30,
        "country" => "KE"
      }
    }

    # Generate the expected signature using the same algorithm
    flat_string = "age=30&country=KE&name=Tester"
    expected_signature = Digest::SHA256.hexdigest(flat_string)

    # Add signature to request body
    request_body["signature"] = expected_signature

    assert_nothing_raised do
      @validator.validate_webhook!(request_body, expected_signature)
    end
  end

  test "rejects incorrect signature" do
    request_body = {
      "name" => "Tester",
      "meta" => {
        "age" => 30,
        "country" => "KE"
      },
      "signature" => "invalid_signature"
    }

    assert_raises(SignatureValidator::Error) do
      @validator.validate_webhook!(request_body, "invalid_signature")
    end
  end

  test "handles nested arrays correctly" do
    request_body = {
      "items" => [
        { "id" => 1, "name" => "Item 1" },
        { "id" => 2, "name" => "Item 2" }
      ],
      "name" => "Tester"
    }

    # Generate the expected signature
    flat_string = "items[0].id=1&items[0].name=Item 1&items[1].id=2&items[1].name=Item 2&name=Tester"
    expected_signature = Digest::SHA256.hexdigest(flat_string)

    request_body["signature"] = expected_signature

    assert_nothing_raised do
      @validator.validate_webhook!(request_body, expected_signature)
    end
  end

  test "handles nil values correctly" do
    request_body = {
      "name" => "Tester",
      "meta" => {
        "age" => 30,
        "country" => nil,
        "city" => "Nairobi"
      }
    }

    # Generate the expected signature (nil values should be excluded)
    flat_string = "age=30&city=Nairobi&name=Tester"
    expected_signature = Digest::SHA256.hexdigest(flat_string)

    request_body["signature"] = expected_signature

    assert_nothing_raised do
      @validator.validate_webhook!(request_body, expected_signature)
    end
  end

  test "sorts keys alphabetically" do
    request_body = {
      "zebra" => "last",
      "alpha" => "first",
      "beta" => "second"
    }

    # Generate the expected signature (should be sorted alphabetically)
    flat_string = "alpha=first&beta=second&zebra=last"
    expected_signature = Digest::SHA256.hexdigest(flat_string)

    request_body["signature"] = expected_signature

    assert_nothing_raised do
      @validator.validate_webhook!(request_body, expected_signature)
    end
  end

  test "excludes signature field from validation" do
    request_body = {
      "name" => "Tester",
      "signature" => "some_signature_here"
    }

    # Generate the expected signature (signature field should be excluded)
    flat_string = "name=Tester"
    expected_signature = Digest::SHA256.hexdigest(flat_string)

    request_body["signature"] = expected_signature

    assert_nothing_raised do
      @validator.validate_webhook!(request_body, expected_signature)
    end
  end
end