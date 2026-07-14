require "test_helper"

class Family::AutoCategorizerTest < ActiveSupport::TestCase
  include EntriesTestHelper, ProviderTestHelper

  setup do
    @family = families(:dylan_family)
    @account = @family.accounts.create!(name: "Rule test", balance: 100, currency: "USD", accountable: Depository.new)
    @llm_provider = mock
    Provider::Registry.stubs(:get_provider).with(:openai).returns(@llm_provider)
  end

  test "auto-categorizes transactions" do
    txn1 = create_transaction(account: @account, name: "McDonalds").transaction
    txn2 = create_transaction(account: @account, name: "Amazon purchase").transaction
    txn3 = create_transaction(account: @account, name: "Netflix subscription").transaction

    test_category = @family.categories.create!(name: "Test category")

    provider_response = provider_success_response([
      AutoCategorization.new(transaction_id: txn1.id, category_name: test_category.name),
      AutoCategorization.new(transaction_id: txn2.id, category_name: test_category.name),
      AutoCategorization.new(transaction_id: txn3.id, category_name: nil)
    ])

    @llm_provider.expects(:auto_categorize).returns(provider_response).once

    assert_difference "DataEnrichment.count", 2 do
      Family::AutoCategorizer.new(@family, transaction_ids: [ txn1.id, txn2.id, txn3.id ]).auto_categorize
    end

    assert_equal test_category, txn1.reload.category
    assert_equal test_category, txn2.reload.category
    assert_nil txn3.reload.category

    # After auto-categorization, only successfully categorized transactions are locked
    # txn3 remains enrichable since it didn't get a category (allows retry)
    assert_equal 1, @account.transactions.reload.enrichable(:category_id).count
  end

  test "includes nearby non-transfer categorization examples in the provider payload" do
    example_category = @family.categories.create!(name: "Coffee")

    target_txn = create_transaction(account: @account, name: "May target", date: Date.new(2025, 5, 20)).transaction
    nearby_past = create_transaction(account: @account, name: "April example", date: Date.new(2025, 4, 15), category: example_category).transaction
    nearby_future = create_transaction(account: @account, name: "July example", date: Date.new(2025, 7, 15), category: example_category).transaction
    far_future = create_transaction(account: @account, name: "July 2026 example", date: Date.new(2026, 7, 15), category: example_category).transaction
    transfer_example = create_transaction(account: @account, name: "Transfer example", date: Date.new(2025, 5, 25), category: example_category, kind: "funds_movement").transaction

    provider_response = provider_success_response([
      AutoCategorization.new(transaction_id: target_txn.id, category_name: example_category.name)
    ])

    @llm_provider.expects(:auto_categorize).with do |transactions:, user_categories:, family:, category_examples:|
      assert_equal @family, family
      assert_equal [ "April example", "July example" ], category_examples.map { |example| example[:description] }
      assert_equal target_txn.id, transactions.first[:id]
      assert_not_includes category_examples.map { |example| example[:description] }, "Transfer example"
      assert_not_includes category_examples.map { |example| example[:description] }, "July 2026 example"
      true
    end.returns(provider_response).once

    Family::AutoCategorizer.new(@family, transaction_ids: [ target_txn.id ]).auto_categorize
  end

  private
    AutoCategorization = Provider::LlmConcept::AutoCategorization
end
