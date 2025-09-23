Rails.application.configure do
  config.x.brand_name = ENV.fetch("BRAND_NAME", "FOSS")
  config.x.product_name = ENV.fetch("PRODUCT_NAME", "Sure")
end
