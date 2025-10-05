require "test_helper"

class PartnersTest < ActiveSupport::TestCase
  setup do
    Partners.reset!
  end

  test "default partner loads from configuration" do
    partner = Partners.default

    assert_not_nil partner
    assert_equal "chancen-ke", partner.key
    assert_equal "Chancen Kenya", partner.name
    assert_equal "financial", partner.type
    assert_equal %w[key name type], partner.required_metadata_keys
  end

  test "partner configuration provides default metadata" do
    partner = Partners.find("chancen-ke")

    assert_not_nil partner
    assert_not_nil partner.default_metadata
    assert_equal "chancen-ke", partner.default_metadata["key"]
    assert_equal "Chancen Kenya", partner.default_metadata["name"]
    assert_equal "financial", partner.default_metadata["type"]
    assert_equal ["Choice Bank"], partner.default_metadata["bank_array"]
  end
  end

  test "reset clears cached registry" do
    Partners.default
    Partners.reset!

    assert_nil Partners.registry
  end
end
