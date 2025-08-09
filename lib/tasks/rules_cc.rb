namespace :rules_cc do
  desc "Run all transaction rules for a specific user (by email)"
  task :run, [ :email ] => :environment do |task, args|
    start = Time.now

    # Validate email argument
    if args[:email].blank?
      puts "❌ Error: Please provide an email address"
      puts "Usage: rails rules:run[user@example.com]"
      exit 1
    end

    puts "🚀 Running transaction rules for #{args[:email]}..."
    puts ""
    
    # Find user
    user = User.find_by(email: args[:email])
    
    if user.nil?
      puts "❌ Error: User with email '#{args[:email]}' not found"
      exit 1
    end
    
    # Get user's family
    family = user.family
    
    if family.nil?
      puts "❌ Error: User '#{args[:email]}' does not belong to a family"
      exit 1
    end
    
    puts "👤 User: #{user.email} (#{user.display_name || 'No display name'})"
    puts "👨‍👩‍👧‍👦 Family: #{family.name || 'Unnamed family'} (ID: #{family.id})"
    puts ""
    
    # Get all rules for the family
    rules = family.rules
    
    if rules.empty?
      puts "⚠️  No rules found for this family"
      exit 0
    end
    
    puts "📋 Found #{rules.count} rule(s) to apply"
    puts "-" * 50
    
    total_matches = 0
    total_applied = 0
    errors = []
    
    rules.each_with_index do |rule, index|
      rule_start = Time.now
      
      puts ""
      puts "#{index + 1}. #{rule.name || 'Unnamed rule'} (ID: #{rule.id})"
      puts "   Type: #{rule.resource_type}"
      
      begin
        # Get matching resources count before applying
        match_count = rule.affected_resource_count
        
        puts "   ✓ Conditions match: #{match_count} #{rule.resource_type.downcase.pluralize}"
        total_matches += match_count
        
        if match_count > 0
          # Apply the rule
          rule.apply
          
          # Count actions applied
          action_descriptions = rule.actions.map do |action|
            case action.action_type
            when "set_transaction_category"
              category = family.categories.find_by(id: action.value)
              "Set category to '#{category&.name || 'Unknown'}'"
            when "set_transaction_merchant"
              merchant = family.merchants.find_by(id: action.value)
              "Set merchant to '#{merchant&.name || 'Unknown'}'"
            when "set_transaction_name"
              "Set name to '#{action.value}'"
            when "set_transaction_tags"
              tag = family.tags.find_by(id: action.value)
              "Add tag '#{tag&.name || 'Unknown'}'"
            when "auto_categorize"
              "Auto-categorize with AI"
            when "auto_detect_merchants"
              "Auto-detect merchants with AI"
            else
              action.action_type.humanize
            end
          end
          
          action_descriptions.each do |desc|
            puts "   → Action: #{desc}"
          end
          
          total_applied += match_count
          puts "   ✅ Applied successfully to #{match_count} item(s)"
        else
          puts "   ⏭️  Skipped (no matches)"
        end
        
        elapsed = ((Time.now - rule_start) * 1000).round(2)
        puts "   ⏱️  Time: #{elapsed}ms"
        
      rescue => e
        errors << { rule: rule, error: e }
        puts "   ❌ Error: #{e.message}"
        puts "   ⏱️  Time: #{((Time.now - rule_start) * 1000).round(2)}ms"
      end
    end
    
    puts ""
    puts "-" * 50
    puts "📊 Summary"
    puts "-" * 50
    puts "Total rules processed:     #{rules.count}"
    puts "Total matches found:       #{total_matches}"
    puts "Total changes applied:     #{total_applied}"
    puts "Errors encountered:        #{errors.count}"
    
    if errors.any?
      puts ""
      puts "⚠️  Errors:"
      errors.each do |error_info|
        puts "  - Rule '#{error_info[:rule].name}': #{error_info[:error].message}"
      end
    end
    
    elapsed = Time.now - start
    puts ""
    puts "✅ Done in #{elapsed.round(2)}s"
  end
  
  desc "Dry run - show what rules would do without applying them"
  task :dry_run, [:email] => :environment do |task, args|
    start = Time.now
    
    # Validate email argument
    if args[:email].blank?
      puts "❌ Error: Please provide an email address"
      puts "Usage: rails rules:dry_run[user@example.com]"
      exit 1
    end
    
    puts "🔍 Dry run: Analyzing transaction rules for #{args[:email]}..."
    puts ""
    
    # Find user
    user = User.find_by(email: args[:email])
    
    if user.nil?
      puts "❌ Error: User with email '#{args[:email]}' not found"
      exit 1
    end
    
    # Get user's family
    family = user.family
    
    if family.nil?
      puts "❌ Error: User '#{args[:email]}' does not belong to a family"
      exit 1
    end
    
    puts "👤 User: #{user.email} (#{user.display_name || 'No display name'})"
    puts "👨‍👩‍👧‍👦 Family: #{family.name || 'Unnamed family'} (ID: #{family.id})"
    puts ""
    
    # Get all rules for the family
    rules = family.rules
    
    if rules.empty?
      puts "⚠️  No rules found for this family"
      exit 0
    end
    
    puts "📋 Found #{rules.count} rule(s)"
    puts "-" * 50
    
    total_matches = 0
    
    rules.each_with_index do |rule, index|
      puts ""
      puts "#{index + 1}. #{rule.name || 'Unnamed rule'} (ID: #{rule.id})"
      puts "   Type: #{rule.resource_type}"
      
      # Get matching resources count
      match_count = rule.affected_resource_count
      
      puts "   Would match: #{match_count} #{rule.resource_type.downcase.pluralize}"
      total_matches += match_count
      
      # Show what actions would be taken
      if rule.actions.any?
        puts "   Actions that would be applied:"
        rule.actions.each do |action|
          case action.action_type
          when "set_transaction_category"
            category = family.categories.find_by(id: action.value)
            puts "     → Set category to '#{category&.name || 'Unknown'}'"
          when "set_transaction_merchant"
            merchant = family.merchants.find_by(id: action.value)
            puts "     → Set merchant to '#{merchant&.name || 'Unknown'}'"
          when "set_transaction_name"
            puts "     → Set name to '#{action.value}'"
          when "set_transaction_tags"
            tag = family.tags.find_by(id: action.value)
            puts "     → Add tag '#{tag&.name || 'Unknown'}'"
          when "auto_categorize"
            puts "     → Auto-categorize with AI"
          when "auto_detect_merchants"
            puts "     → Auto-detect merchants with AI"
          else
            puts "     → #{action.action_type.humanize}"
          end
        end
      end
    end

    puts ""
    puts "-" * 50
    puts "📊 Dry Run Summary"
    puts "-" * 50
    puts "Total rules analyzed:      #{rules.count}"
    puts "Total matches found:       #{total_matches}"
    puts "No changes were made (dry run)"

    elapsed = Time.now - start
    puts ""
    puts "✅ Analysis complete in #{elapsed.round(2)}s"
  end
end
