require "test_helper"

class OauthRoutesTest < ActionDispatch::IntegrationTest
  test "oauth callback route exists" do
    assert_routing "/auth/twitter2/callback", { controller: "oauth", action: "callback", provider: "twitter2" }
  end

  test "oauth disconnect route exists" do
    assert_routing({ method: "post", path: "/auth/twitter2/disconnect" }, 
                   { controller: "oauth", action: "disconnect", provider: "twitter2" })
  end

  test "twitter oauth redirect works" do
    get "/auth/twitter2"
    assert_response :redirect
  end
end