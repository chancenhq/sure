namespace :rules do
  desc "Run all transaction rules for a user by email"
  task :run, [:email] => :environment do |task, args|
    start = Time.now
    
    # Validate email argument
    if args[:email].blank?
      puts "❌ Error: Please provide an email address"
      puts "Usage: rails rules:run[user@example.com]"
      exit 1
    end
    
    puts "🚀 Running transaction rules for #{args[:email]}..."
    
    # Find user
    user = User.find_by(email: args[:email])
    
    if user.nil?
      puts "❌ Error: User with email '#{args[:email]}' not found"
      exit 1
    end
    
    family = user.family
    
    if family.nil?
      puts "❌ Error: User '#{args[:email]}' does not belong to a family"
      exit 1
    end
    
    puts "👤 User: #{user.email}"
    puts "👨‍👩‍👧‍👦 Family: #{family.name || 'Unnamed family'}"
    puts ""
    
    # Get all rules for the family
    rules = family.rules
    
    if rules.empty?
      puts "⚠️  No rules found for this family"
      exit 0
    end
    
    puts "📋 Found #{rules.count} rule(s) to apply"
    puts ""
    
    total_matches = 0
    total_applied = 0
    
    rules.each_with_index do |rule, index|
      puts "#{index + 1}. #{rule.name || 'Unnamed rule'}"
      
      begin
        # Get matching resources count before applying
        match_count = rule.affected_resource_count
        
        puts "   ✓ Matches: #{match_count} #{rule.resource_type.downcase.pluralize}"
        total_matches += match_count
        
        if match_count > 0
          # Get the matching transactions before applying rules
          matching_transactions = rule.registry.resource_scope
          
          # Store before state for categories and merchants
          before_states = {}
          matching_transactions.each do |transaction|
            before_states[transaction.id] = {
              category: transaction.category&.name,
              merchant: transaction.merchant&.name
            }
          end
          
          # Count action types
          immediate_changes = rule.actions.count { |action| !%w[auto_categorize auto_detect_merchants].include?(action.action_type) }
          ai_changes = rule.actions.count { |action| %w[auto_categorize auto_detect_merchants].include?(action.action_type) }
          
          puts "   Debug: Rule has #{rule.actions.count} actions"
          puts "   Debug: Immediate actions: #{immediate_changes}, AI actions: #{ai_changes}"
          puts "   Debug: Rails.env.development? = #{Rails.env.development?}"
          puts "   Debug: AI provider available? #{Provider::Registry.get_provider(:openai).present?}"
          
          # In development mode, we need to execute AI actions synchronously
          if Rails.env.development? && ai_changes > 0
            puts "   🔄 Executing AI actions synchronously (development mode)..."
            
            # Unlock attributes for AI processing in development mode
            puts "   Debug: Unlocking attributes for AI processing..."
            unlocked_categories = 0
            unlocked_merchants = 0
            locked_categories = 0
            locked_merchants = 0
            matching_transactions.each do |transaction|
              if transaction.locked?(:category_id)
                transaction.unlock_attr!(:category_id)
                unlocked_categories += 1
              end
              if transaction.locked?(:merchant_id)
                transaction.unlock_attr!(:merchant_id)
                unlocked_merchants += 1
              end
            end
            puts "   Debug: Unlocked #{unlocked_categories} category attributes, #{unlocked_merchants} merchant attributes"
            
            # Check enrichable status after unlocking
            enrichable_categories = matching_transactions.count { |t| t.enrichable?(:category_id) }
            enrichable_merchants = matching_transactions.count { |t| t.enrichable?(:merchant_id) }
            puts "   Debug: After unlocking - enrichable categories: #{enrichable_categories}, enrichable merchants: #{enrichable_merchants}"
            
            # Apply immediate actions first
            rule.actions.each do |action|
              unless %w[auto_categorize auto_detect_merchants].include?(action.action_type)
                action.apply(matching_transactions, ignore_attribute_locks: false)
              end
            end
            
            # Execute AI actions synchronously
            rule.actions.each do |action|
              puts "   Debug: Processing action: #{action.action_type}"
              case action.action_type
              when "auto_categorize"
                puts "      → Executing auto-categorize..."
                puts "   Debug: Checking #{matching_transactions.count} transactions for category enrichment"
                matching_transactions.first(3).each do |t|
                  puts "   Debug: Transaction #{t.id} - category_id: #{t.category_id}, enrichable?: #{t.enrichable?(:category_id)}, locked?: #{t.locked?(:category_id)}"
                end
                enrichable_transactions = matching_transactions.select { |t| t.enrichable?(:category_id) }
                puts "   Debug: Found #{enrichable_transactions.count} enrichable transactions for category"
                if enrichable_transactions.any?
                  puts "   Debug: Calling family.auto_categorize_transactions..."
                  puts "   Debug: AI provider available? #{Provider::Registry.get_provider(:openai).present?}"
                  begin
                    family.auto_categorize_transactions(enrichable_transactions.map(&:id))
                    puts "      → Auto-categorize completed"
                  rescue => e
                    puts "   Debug: Error in auto_categorize: #{e.message}"
                    puts "   Debug: Error class: #{e.class}"
                  end
                else
                  puts "   Debug: No enrichable transactions found for auto-categorize"
                end
              when "auto_detect_merchants"
                puts "      → Executing auto-detect merchants..."
                puts "   Debug: Checking #{matching_transactions.count} transactions for merchant enrichment"
                matching_transactions.first(3).each do |t|
                  puts "   Debug: Transaction #{t.id} - merchant_id: #{t.merchant_id}, enrichable?: #{t.enrichable?(:merchant_id)}, locked?: #{t.locked?(:merchant_id)}"
                end
                enrichable_transactions = matching_transactions.select { |t| t.enrichable?(:merchant_id) }
                puts "   Debug: Found #{enrichable_transactions.count} enrichable transactions for merchant"
                if enrichable_transactions.any?
                  puts "   Debug: Calling family.auto_detect_transaction_merchants..."
                  puts "   Debug: AI provider available? #{Provider::Registry.get_provider(:openai).present?}"
                  begin
                    family.auto_detect_transaction_merchants(enrichable_transactions.map(&:id))
                    puts "      → Auto-detect merchants completed"
                  rescue => e
                    puts "   Debug: Error in auto_detect_merchants: #{e.message}"
                    puts "   Debug: Error class: #{e.class}"
                  end
                else
                  puts "   Debug: No enrichable transactions found for auto-detect merchants"
                end
              end
            end
          else
            # Apply the rule normally (includes background job scheduling for AI actions)
            rule.apply
          end
          
          if immediate_changes > 0
            total_applied += match_count
            puts "   ✅ Applied successfully"
          elsif ai_changes > 0
            if Rails.env.development?
              total_applied += match_count
              puts "   ✅ Applied successfully (AI actions executed synchronously)"
            else
              puts "   ⏳ Scheduled for background processing"
            end
          else
            puts "   ✅ Applied successfully"
          end
          
          # Log what changes were made
          puts "   📝 Changes applied:"
          rule.actions.each do |action|
            case action.action_type
            when "set_transaction_category"
              category = family.categories.find_by(id: action.value)
              puts "      → Set category to '#{category&.name || 'Unknown'}'"
            when "set_transaction_merchant"
              merchant = family.merchants.find_by(id: action.value)
              puts "      → Set merchant to '#{merchant&.name || 'Unknown'}'"
            when "set_transaction_name"
              puts "      → Set name to '#{action.value}'"
            when "set_transaction_tags"
              tag = family.tags.find_by(id: action.value)
              puts "      → Added tag '#{tag&.name || 'Unknown'}'"
            when "auto_categorize"
              puts "      → Auto-categorize with AI (enqueued for background processing)"
            when "auto_detect_merchants"
              puts "      → Auto-detect merchants with AI (enqueued for background processing)"
            else
              puts "      → #{action.action_type.humanize}"
            end
          end
          
          # Show transaction details
          puts "   📋 Affected transactions:"
          matching_transactions.each do |transaction|
            before_state = before_states[transaction.id]
            after_category = transaction.category&.name || "None"
            after_merchant = transaction.merchant&.name || "None"
            
            category_change = before_state[:category] != after_category ? 
              " (#{before_state[:category] || 'None'} → #{after_category})" : ""
            merchant_change = before_state[:merchant] != after_merchant ? 
              " (#{before_state[:merchant] || 'None'} → #{after_merchant})" : ""
            
            puts "      • #{transaction.entry.name} (#{transaction.entry.date}) - $#{transaction.entry.amount.abs}"
            puts "        Category: #{after_category}#{category_change}"
            puts "        Merchant: #{after_merchant}#{merchant_change}"
          end
        else
          puts "   ⏭️  Skipped (no matches)"
        end
        
      rescue => e
        puts "   ❌ Error: #{e.message}"
      end
    end

    puts ""
    puts "📊 Summary:"
    puts "   Total rules processed: #{rules.count}"
    puts "   Total matches found: #{total_matches}"
    puts "   Total changes applied: #{total_applied}"
    
    elapsed = Time.now - start
    puts ""
    puts "✅ Done in #{elapsed.round(2)}s"
  end
end
