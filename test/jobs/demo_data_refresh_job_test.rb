require "test_helper"

class DemoDataRefreshJobTest < ActiveJob::TestCase
  OVERRIDE_ENV = "ALLOW_DEMO_DATA_OVERRIDE"

  def setup
    @previous_override = ENV[OVERRIDE_ENV]
    ENV.delete(OVERRIDE_ENV)
  end

  def teardown
    if @previous_override
      ENV[OVERRIDE_ENV] = @previous_override
    else
      ENV.delete(OVERRIDE_ENV)
    end
  end

  test "refreshes demo data using the generator" do
    generator = Minitest::Mock.new
    generator.expect(:generate_default_data!, nil, [], email: "user@example.com")

    Demo::Generator.stub :new, ->(**kwargs) {
      assert_equal false, kwargs.fetch(:allow_production)
      generator
    } do
      DemoDataRefreshJob.perform_now
    end

    generator.verify
  end

  test "allows production override when enabled" do
    ENV[OVERRIDE_ENV] = "true"

    generator = Minitest::Mock.new
    generator.expect(:generate_default_data!, nil, [], email: "user@example.com")

    Demo::Generator.stub :new, ->(**kwargs) {
      assert kwargs.fetch(:allow_production)
      generator
    } do
      DemoDataRefreshJob.perform_now
    end

    generator.verify
  end

  test "does not run in production without override" do
    Rails.stub :env, ActiveSupport::StringInquirer.new("production") do
      generator_called = false

      Demo::Generator.stub(:new, ->(**_) { generator_called = true }) do
        DemoDataRefreshJob.perform_now
      end

      assert_not generator_called
    end
  end
end
