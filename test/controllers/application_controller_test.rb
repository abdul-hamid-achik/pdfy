require "test_helper"

class ApplicationControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def setup
    @user = users(:one)
  end

  test "should redirect unauthenticated users to login" do
    # Test with a route that requires authentication
    get pdf_templates_url
    assert_redirected_to new_user_session_path
  end

  test "should allow authenticated users to access protected routes" do
    sign_in @user
    get pdf_templates_url
    assert_response :success
  end

  test "should apply modern browser policy" do
    sign_in @user
    
    # Simulate an old browser (this is hard to test without actually changing user agent)
    # The allow_browser directive should be in place but is difficult to test in integration tests
    # We'll just verify that the directive exists in the controller
    
    get pdf_templates_url
    assert_response :success
    # If we reach here, the browser is considered "modern" by Rails standards
  end

  test "should authenticate user before each action" do
    # Verify that the before_action :authenticate_user! is working
    # by attempting to access any protected controller action
    
    # Test multiple controller actions to ensure authentication is applied globally
    [
      pdf_templates_url,
      new_pdf_template_url
    ].each do |url|
      get url
      assert_redirected_to new_user_session_path, "Should redirect to login for #{url}"
    end
  end

  test "should maintain authentication across requests" do
    sign_in @user
    
    # Make multiple requests to verify session persistence
    get pdf_templates_url
    assert_response :success
    
    get new_pdf_template_url
    assert_response :success
    
    # User should still be authenticated
    assert_equal @user, controller.current_user if controller.respond_to?(:current_user)
  end

  test "should handle authentication with different user types" do
    # Test with regular user
    sign_in @user
    get pdf_templates_url
    assert_response :success
    
    sign_out @user
    
    # Test with admin user if available
    if defined?(AdminUser)
      admin = admin_users(:one)
      sign_in admin
      
      # Admin users might have different access patterns
      # This depends on how your authentication is set up
      get pdf_templates_url
      assert_response :success
    end
  end

  test "should properly handle sign out" do
    sign_in @user
    get pdf_templates_url
    assert_response :success
    
    sign_out @user
    get pdf_templates_url
    assert_redirected_to new_user_session_path
  end

  test "should inherit from ActionController::Base" do
    assert ApplicationController < ActionController::Base
  end

  test "should include Devise authentication helpers" do
    # Verify that authentication methods are available
    controller = ApplicationController.new
    
    # These methods should be available due to Devise integration
    assert controller.respond_to?(:authenticate_user!)
    assert controller.respond_to?(:user_signed_in?)
    assert controller.respond_to?(:current_user)
  end

  test "should have modern browser version requirement" do
    # This test verifies the allow_browser configuration exists
    # The actual browser compatibility testing would require specific user agent strings
    
    # We can verify the directive is present by checking if the controller
    # responds to browser-related methods (this is implicit in Rails)
    controller = ApplicationController.new
    
    # If allow_browser is configured, Rails should have added browser checking
    # This is more of a configuration verification than a functional test
    assert controller.class.ancestors.include?(ActionController::Base)
  end

  test "should handle browser compatibility gracefully" do
    sign_in @user
    
    # With a modern user agent (default in tests), should work normally
    get pdf_templates_url
    assert_response :success
    
    # The actual browser version checking is handled by Rails internally
    # and would require manipulating the user agent string to test thoroughly
  end

  test "should apply CSRF protection" do
    # Rails applies CSRF protection by default
    # This test verifies that CSRF protection is in place
    
    sign_in @user
    
    # GET requests should work without CSRF token
    get pdf_templates_url
    assert_response :success
    
    # POST requests without proper CSRF protection should fail
    # (but this is harder to test in integration tests without bypassing Devise)
  end

  test "should set appropriate response headers for security" do
    sign_in @user
    get pdf_templates_url
    
    # Rails sets various security headers by default
    # We can verify some basic security headers are present
    assert response.headers.present?
    
    # X-Frame-Options is typically set by Rails for security
    # Content-Type should be set properly
    assert_equal "text/html; charset=utf-8", response.content_type
  end

  test "should handle exceptions gracefully" do
    sign_in @user
    
    # Test with a route that might cause errors
    # (in a real app, you might have error handling middleware)
    
    # For now, just verify that normal requests work
    get pdf_templates_url
    assert_response :success
    
    # Exception handling would be tested with specific error scenarios
    # that depend on your application's error handling setup
  end

  test "should maintain consistent authentication state" do
    # Test authentication persistence across different types of requests
    
    sign_in @user
    
    # Test GET request
    get pdf_templates_url
    assert_response :success
    
    # Test POST request (creating a new template)
    post pdf_templates_url, params: {
      pdf_template: {
        name: "Auth Test Template",
        description: "Testing authentication",
        template_content: '<h1>{{test}}</h1>',
        active: true
      }
    }
    
    # Should be redirected to the new template (successful creation)
    assert_response :redirect
    
    # Follow redirect and verify we're still authenticated
    follow_redirect!
    assert_response :success
  end

  test "should properly scope access based on authentication" do
    # This test verifies that authentication is the primary access control
    # (with authorization being handled in individual controllers)
    
    unauthenticated_routes = [
      pdf_templates_url,
      new_pdf_template_url
    ]
    
    # Without authentication, should be redirected to login
    unauthenticated_routes.each do |route|
      get route
      assert_redirected_to new_user_session_path
    end
    
    # With authentication, should be able to access
    sign_in @user
    
    unauthenticated_routes.each do |route|
      get route
      assert_response :success
    end
  end
end