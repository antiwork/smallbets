require "test_helper"

class StatsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:david)
    post "/session", params: { email: @user.email_address, password: "secret123456" }
  end

  test "index with default range renders successfully" do
    get "/stats"
    assert_response :success
    assert_select "select[name='range'] option[value='all'][selected]"
  end

  test "index with range=90 renders successfully" do
    get "/stats", params: { range: "90" }
    assert_response :success
    assert_select "select[name='range'] option[value='90'][selected]"
  end

  test "index with range=365 renders successfully" do
    get "/stats", params: { range: "365" }
    assert_response :success
    assert_select "select[name='range'] option[value='365'][selected]"
  end

  test "index with invalid range defaults to all" do
    get "/stats", params: { range: "invalid" }
    assert_response :success
    assert_select "select[name='range'] option[value='all'][selected]"
  end

  test "chart_stats is set correctly for different ranges" do
    get "/stats", params: { range: "90" }
    assert_response :success
    assert_not_nil assigns(:chart_stats)
    assert_not_nil assigns(:range)
    assert_equal "90", assigns(:range)
  end
end
