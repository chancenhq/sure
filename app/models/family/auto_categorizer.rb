class Family::AutoCategorizer
  Error = Class.new(StandardError)

  def initialize(family, transaction_ids: [])
    @family = family
    @transaction_ids = transaction_ids
  end

  def auto_categorize
    raise Error, "No LLM provider for auto-categorization" unless llm_provider

    if scope.none?
      Rails.logger.info("No transactions to auto-categorize for family #{family.id}")
      return 0
    else
      Rails.logger.info("Auto-categorizing #{scope.count} transactions for family #{family.id}")
    end

    categories_input = user_categories_input

    if categories_input.empty?
      Rails.logger.error("Cannot auto-categorize transactions for family #{family.id}: no categories available")
      return 0
    end

    result = llm_provider.auto_categorize(
      transactions: transactions_input,
      user_categories: categories_input,
      family: family,
      category_examples: category_examples_input
    )

    unless result.success?
      Rails.logger.error("Failed to auto-categorize transactions for family #{family.id}: #{result.error.message}")
      return 0
    end

    modified_count = 0
    scope.each do |transaction|
      auto_categorization = result.data.find { |c| c.transaction_id == transaction.id }

      category_id = categories_input.find { |c| c[:name] == auto_categorization&.category_name }&.dig(:id)

      if category_id.present?
        was_modified = transaction.enrich_attribute(
          :category_id,
          category_id,
          source: "ai"
        )
        transaction.lock_attr!(:category_id)
        # enrich_attribute returns true if the transaction was actually modified
        modified_count += 1 if was_modified
      end
    end

    modified_count
  end

  private
    attr_reader :family, :transaction_ids

    # For now, OpenAI only, but this should work with any LLM concept provider
    def llm_provider
      Provider::Registry.get_provider(:openai)
    end

    def user_categories_input
      family.categories.map do |category|
        {
          id: category.id,
          name: category.name,
          is_subcategory: category.subcategory?,
          parent_id: category.parent_id
        }
      end
    end

    def transactions_input
      scope.map do |transaction|
        name = transaction.entry.name.presence
        notes = transaction.entry.notes.presence
        description = [ name, notes ].compact.reject(&:empty?).join(" | ")

        {
          id: transaction.id,
          amount: transaction.entry.amount.abs,
          classification: transaction.entry.classification,
          name: name,
          description: description,
          notes: notes,
          merchant: transaction.merchant&.name
        }
      end
    end

    def category_examples_input
      target_dates = scope.map { |transaction| transaction.entry.date }.compact
      return [] if target_dates.empty?

      earliest_date = target_dates.min - 3.months
      latest_date = target_dates.max + 3.months

      candidate_transactions = family.transactions
        .includes(:category, :merchant, :entry)
        .where.not(category_id: nil)
        .where.not(transactions: { kind: Transaction::TRANSFER_KINDS })
        .where(entries: { date: earliest_date..latest_date })
        .to_a

      candidate_transactions
        .sort_by { |transaction| [ target_dates.map { |date| (transaction.entry.date - date).abs }.min, transaction.entry.date ] }
        .first(20)
        .map do |transaction|
          {
            transaction_id: transaction.id,
            category_name: transaction.category&.name,
            description: [ transaction.entry.name, transaction.entry.notes ].compact.reject(&:empty?).join(" | "),
            merchant: transaction.merchant&.name,
            amount: transaction.entry.amount.abs,
            classification: transaction.entry.classification
          }
        end
    end

    def scope
      family.transactions.where(id: transaction_ids, category_id: nil)
                         .enrichable(:category_id)
                         .includes(:category, :merchant, :entry)
    end
end
