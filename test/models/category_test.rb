require "test_helper"

class CategoryTest < ActiveSupport::TestCase
  def setup
    @family = families(:dylan_family)
  end

  test "replacing and destroying" do
    transactions = categories(:food_and_drink).transactions.to_a

    categories(:food_and_drink).replace_and_destroy!(categories(:income))

    assert_equal categories(:income), transactions.map { |t| t.reload.category }.uniq.first
  end

  test "replacing with nil should nullify the category" do
    transactions = categories(:food_and_drink).transactions.to_a

    categories(:food_and_drink).replace_and_destroy!(nil)

    assert_nil transactions.map { |t| t.reload.category }.uniq.first
  end

  test "subcategory can only be one level deep" do
    category = categories(:subcategory)

    error = assert_raises(ActiveRecord::RecordInvalid) do
      category.subcategories.create!(name: "Invalid category", family: @family)
    end

    assert_equal "Validation failed: Parent can't have more than 2 levels of subcategories", error.message
  end

  test "all_investment_contributions_names returns all locale variants" do
    names = Category.all_investment_contributions_names

    assert_includes names, "Investment Contributions"  # English
    assert_includes names, "Contributions aux investissements"  # French
    assert_includes names, "Investeringsbijdragen"  # Dutch
    assert names.all? { |name| name.is_a?(String) }
    assert_equal names, names.uniq  # No duplicates
  end

  test "bootstrap creates the requested default income and expense categories" do
    @family.categories.where(name: [ "Income", "Salary", "Other income", "Uncategorized", "Credit from own account", "Fixed expenses", "Supermarket", "Transport", "Well-being", "Other expenses", "Debit to own account" ]).destroy_all

    @family.categories.bootstrap!

    income = @family.categories.find_by!(name: "Income")
    salary = @family.categories.find_by!(name: "Salary")
    supermarket = @family.categories.find_by!(name: "Supermarket")
    fixed_expenses = @family.categories.find_by!(name: "Fixed expenses")
    everyday_essentials = @family.categories.find_by!(name: "Everyday essentials")
    debit_to_own_account = @family.categories.find_by!(name: "Debit to own account")

    assert_equal income, salary.parent
    assert_equal "income", income.reload.classification_unused
    assert_equal "expense", fixed_expenses.reload.classification_unused
    assert_equal everyday_essentials, supermarket.parent
    assert_equal "expense", debit_to_own_account.reload.classification_unused
  end

  test "should accept valid 6-digit hex colors" do
    [ "#FFFFFF", "#000000", "#123456", "#ABCDEF", "#abcdef" ].each do |color|
      category = Category.new(name: "Category #{color}", color: color, lucide_icon: "shapes", family: @family)
      assert category.valid?, "#{color} should be valid"
    end
  end

  test "should reject invalid colors" do
    [ "invalid", "#123", "#1234567", "#GGGGGG", "red", "ffffff", "#ffff", "" ].each do |color|
      category = Category.new(name: "Category #{color}", color: color, lucide_icon: "shapes", family: @family)
      assert_not category.valid?, "#{color} should be invalid"
      assert_includes category.errors[:color], "is invalid"
    end
  end
end
