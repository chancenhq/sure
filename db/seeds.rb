# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

if Rails.env.development?
  puts 'Run `rake demo_data:default` for the USA dataset or `rake demo_data:kenya` for the Kenyan dataset to create demo data.'
end

Dir[Rails.root.join('db', 'seeds', '*.rb')].sort.each do |file|
  puts "Loading seed file: #{File.basename(file)}"
  require file
end
