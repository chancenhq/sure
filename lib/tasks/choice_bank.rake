namespace :choice_bank do
  desc "Test Choice Bank API with stubbed data"
  task test_api: :environment do
    puts "🏦 Testing Choice Bank API Integration"
    puts "=" * 50
    
    # Create a test user object
    test_user = OpenStruct.new(
      id: SecureRandom.uuid,
      email: "test.kenya@example.com",
      display_name: "Test User Kenya",
      family: OpenStruct.new(
        country: "KE",
        currency: "KES"
      )
    )
    
    # Prepare test KYC data
    test_kyc_data = {
      firstName: "Test",
      middleName: "User", 
      lastName: "Kenya",
      birthday: "1990-01-15",
      gender: "M",
      countryCode: "KE",
      mobilePhone: "0712345678",
      idType: "101", # Kenyan National ID
      idNumber: "12345678",
      kraPin: "A123456789B",
      email: test_user.email,
      address: "123 Test Street, Nairobi, Kenya",
      frontSidePhoto: generate_test_image_base64,
      backSidePhoto: generate_test_image_base64,
      selfiePhoto: generate_test_image_base64
    }
    
    puts "📋 Test Data:"
    puts "  User ID: #{test_user.id}"
    puts "  Name: #{test_kyc_data[:firstName]} #{test_kyc_data[:middleName]} #{test_kyc_data[:lastName]}"
    puts "  ID Type: #{test_kyc_data[:idType]} (Kenyan National ID)"
    puts "  ID Number: #{test_kyc_data[:idNumber]}"
    puts "  KRA PIN: #{test_kyc_data[:kraPin]}"
    puts "  Phone: #{test_kyc_data[:mobilePhone]}"
    puts "  Email: #{test_kyc_data[:email]}"
    puts ""
    
    puts "🚀 Submitting KYC to Choice Bank API..."
    puts "  Environment: #{Rails.env}"
    puts "  API URL: #{ChoiceBankApiService::BASE_URL}"
    puts "  Endpoint: #{ChoiceBankApiService::ONBOARDING_ENDPOINT}"
    
    if ENV['CHOICE_BANK_PRIVATE_KEY'].blank?
      puts "\n⚠️  WARNING: CHOICE_BANK_PRIVATE_KEY not set!"
      puts "  The API call will fail without proper authentication."
      puts "  Set the environment variable to proceed with real API calls."
    end
    
    puts ""
    
    # Call the service
    result = ChoiceBankApiService.submit_kyc(test_kyc_data, test_user)
    
    # Display results
    puts "📨 Results:"
    puts "=" * 50
    
    if result[:success]
      puts "✅ SUCCESS!"
      puts "  Account ID: #{result[:account_id]}"
      puts "  Message: #{result[:message]}"
    else
      puts "❌ FAILED!"
      puts "  Error: #{result[:error]}"
    end
    
    puts "=" * 50
    
    # Display verbose output if requested
    if ENV['VERBOSE'].present?
      puts "\n📝 Full Response:"
      puts result.to_json
    end
  end
  
  desc "Test Choice Bank API with real user data (requires user email)"
  task :test_with_user, [:email] => :environment do |t, args|
    unless args[:email]
      puts "❌ ERROR: Please provide a user email"
      puts "Usage: rake choice_bank:test_with_user[user@example.com]"
      exit 1
    end
    
    user = User.find_by(email: args[:email])
    
    unless user
      puts "❌ ERROR: User not found with email: #{args[:email]}"
      exit 1
    end
    
    puts "🏦 Testing Choice Bank API with User: #{user.email}"
    puts "=" * 50
    
    # Prepare KYC data from actual user
    test_kyc_data = {
      firstName: user.first_name || "Test",
      middleName: "",
      lastName: user.last_name || "User",
      birthday: "1990-01-15", # Would need to be collected
      gender: "M", # Would need to be collected
      countryCode: user.family.country || "KE",
      mobilePhone: "0712345678", # Would need to be collected
      idType: "101",
      idNumber: "12345678", # Would need to be collected
      kraPin: "A123456789B", # Would need to be collected
      email: user.email,
      address: "Test Address, Nairobi, Kenya",
      frontSidePhoto: generate_test_image_base64,
      backSidePhoto: generate_test_image_base64,
      selfiePhoto: generate_test_image_base64
    }
    
    puts "📋 User Data:"
    puts "  User ID: #{user.id}"
    puts "  Name: #{user.display_name}"
    puts "  Email: #{user.email}"
    puts "  Country: #{user.family.country}"
    puts "  Currency: #{user.family.currency}"
    puts ""
    
    # Confirm before proceeding
    print "⚠️  This will submit TEST data to Choice Bank API. Continue? (yes/no): "
    confirmation = STDIN.gets.chomp.downcase
    
    unless confirmation == 'yes'
      puts "❌ Aborted by user"
      exit 0
    end
    
    puts "\n🚀 Submitting KYC to Choice Bank API..."
    
    # Call the service
    result = ChoiceBankApiService.submit_kyc(test_kyc_data, user)
    
    # Display results
    puts "\n📨 Results:"
    puts "=" * 50
    
    if result[:success]
      puts "✅ SUCCESS!"
      puts "  Account ID: #{result[:account_id]}"
      puts "  Message: #{result[:message]}"
      
      # Note: In a real scenario, you might want to store the account_id
      puts "\n💡 Note: Account ID would normally be stored in session"
    else
      puts "❌ FAILED!"
      puts "  Error: #{result[:error]}"
    end
    
    puts "=" * 50
  end
  
  private
  
  def generate_test_image_base64
    # Generate a minimal valid PNG image as base64
    # This creates a 1x1 pixel transparent PNG
    png_data = [
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,  # PNG signature
      0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,  # IHDR chunk
      0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
      0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53,
      0xDE, 0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41,  # IDAT chunk
      0x54, 0x08, 0x99, 0x63, 0xF8, 0x0F, 0x00, 0x00,
      0x01, 0x01, 0x01, 0x00, 0x27, 0xDF, 0xD6, 0x8B,
      0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44,  # IEND chunk
      0xAE, 0x42, 0x60, 0x82
    ].pack('C*')
    
    Base64.strict_encode64(png_data)
  end
end