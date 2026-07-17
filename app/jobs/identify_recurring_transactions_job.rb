class IdentifyRecurringTransactionsJob < ApplicationJob
  queue_as :default

  # Debounce: if called multiple times within the delay window,
  # only the last scheduled job will actually run
  DEBOUNCE_DELAY = 30.seconds

  def perform(family_id, scheduled_at)
    family = Family.find_by(id: family_id)
    return unless family
    return if family.recurring_transactions_disabled?

    # Check if this job is stale (a newer one was scheduled)
    latest_scheduled = Rails.cache.read(cache_key(family_id))
    return if latest_scheduled && latest_scheduled > scheduled_at

    # Check if there are still incomplete syncs - if so, skip and let the last sync trigger it
    return if family_has_incomplete_syncs?(family)

    # Use advisory lock as final safety net against concurrent execution
    with_advisory_lock(family_id) do
      RecurringTransaction::Identifier.new(family).identify_recurring_patterns
    end
  end

  def self.schedule_for(family)
    return if family.recurring_transactions_disabled?

    scheduled_at = Time.current.to_f
    cache_key = "recurring_transaction_identify:#{family.id}"

    # Store the latest scheduled time
    Rails.cache.write(cache_key, scheduled_at, expires_in: DEBOUNCE_DELAY + 10.seconds)

    # Schedule the job with delay
    set(wait: DEBOUNCE_DELAY).perform_later(family.id, scheduled_at)
  end

  private

    def cache_key(family_id)
      "recurring_transaction_identify:#{family_id}"
    end

    def family_has_incomplete_syncs?(family)
      fid = family.id

      # Item classes that belong to a family via family_id
      item_classes = [
        PlaidItem, SimplefinItem, LunchflowItem, EnableBankingItem,
        SophtronItem, CoinstatsItem, MercuryItem, BinanceItem,
        CoinbaseItem, SnaptradeItem, IndexaCapitalItem
      ].select { |klass| klass.column_names.include?("family_id") }

      # Build a single query covering Family, all provider item types, and Account
      query = Sync.incomplete.where(syncable_type: "Family", syncable_id: fid)

      item_classes.each do |klass|
        query = query.or(
          Sync.incomplete.where(syncable_type: klass.name, syncable_id: klass.where(family_id: fid).select(:id))
        )
      end

      query = query.or(
        Sync.incomplete.where(syncable_type: "Account", syncable_id: Account.where(family_id: fid).select(:id))
      )

      query.exists?
    end

    def with_advisory_lock(family_id)
      lock_key = advisory_lock_key(family_id)
      acquired = ActiveRecord::Base.connection.select_value(
        ActiveRecord::Base.sanitize_sql_array([ "SELECT pg_try_advisory_lock(?)", lock_key ])
      )

      return unless acquired

      begin
        yield
      ensure
        ActiveRecord::Base.connection.execute(
          ActiveRecord::Base.sanitize_sql_array([ "SELECT pg_advisory_unlock(?)", lock_key ])
        )
      end
    end

    def advisory_lock_key(family_id)
      # Generate a stable integer key from the family ID for PostgreSQL advisory lock
      # Advisory locks require a bigint key
      Digest::MD5.hexdigest("recurring_transaction_identify:#{family_id}").to_i(16) % (2**31)
    end
end
