require "test_helper"

class StaticPagesControllerTest < ActionDispatch::IntegrationTest
  test "should get dashboard" do
    get static_pages_dashboard_url
    assert_response :success
  end

  test "should get landing_page" do
    get static_pages_landing_page_url
    assert_response :success
  end
end
