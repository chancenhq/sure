require "test_helper"

class RootRedirectTest < ActionDispatch::IntegrationTest
  test "unauthenticated visitors are sent to reg ch welcome" do
    get root_path
    assert_redirected_to welcome_reg_chancen_path
  end
end
