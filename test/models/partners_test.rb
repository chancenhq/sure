require "test_helper"

class PartnersTest < ActiveSupport::TestCase
  setup do
    Partners.reset!
  end

  test "default partner loads from configuration" do
    partner = Partners.default

    assert_not_nil partner
    assert_equal "chancen", partner.key
    assert_equal "Chancen", partner.name
    assert_equal "education", partner.type
    assert_equal %w[key name pei bank type], partner.required_metadata_keys
  end

  test "partner configuration provides default metadata" do
    partner = Partners.find(:chancen)

    assert_not_nil partner
    assert_equal({
      "key" => "chancen",
      "name" => "Chancen",
      "pei" => "kenya",
      "bank" => "choice",
      "type" => "education"
    }, partner.default_metadata)
  end

  test "reset clears cached registry" do
    Partners.default
    Partners.reset!

    assert_nil Partners.registry
  end
end
