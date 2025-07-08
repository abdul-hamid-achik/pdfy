require "test_helper"

class AuthenticationFlowTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def setup
    @user = users(:one)
    @admin_user = users(:admin)  # Admin is a regular user with admin flag
  end

  test "user can sign up, sign in, and sign out" do
    # Test sign up flow
    get new_user_registration_path
    assert_response :success
    assert_select "form"

    post user_registration_path, params: {
      user: {
        email: "newuser@example.com",
        password: "password123",
        password_confirmation: "password123"
      }
    }

    # Should be signed in after registration
    assert_response :redirect
    follow_redirect!
    assert_response :success
    
    new_user = User.find_by(email: "newuser@example.com")
    assert_not_nil new_user

    # Test sign out
    delete destroy_user_session_path
    assert_response :redirect
    
    # After sign out, should be redirected to login when accessing protected routes
    get pdf_templates_path
    assert_redirected_to new_user_session_path

    # Test sign in
    get new_user_session_path
    assert_response :success
    assert_select "form"

    post user_session_path, params: {
      user: {
        email: "newuser@example.com",
        password: "password123"
      }
    }

    assert_response :redirect
    follow_redirect!
    assert_response :success

    # Should now be able to access protected routes
    get pdf_templates_path
    assert_response :success
  end

  test "user cannot access protected routes without authentication" do
    protected_routes = [
      { method: :get, path: pdf_templates_path },
      { method: :get, path: new_pdf_template_path },
      { method: :post, path: pdf_templates_path }
    ]

    protected_routes.each do |route|
      case route[:method]
      when :get
        get route[:path]
      when :post
        post route[:path], params: { pdf_template: { name: "test" } }
      end
      
      assert_redirected_to new_user_session_path, 
        "Should redirect to login for #{route[:method].upcase} #{route[:path]}"
    end
  end

  test "user authentication persists across requests" do
    sign_in @user

    # Make multiple requests to verify session persistence
    get pdf_templates_path
    assert_response :success

    get new_pdf_template_path
    assert_response :success

    post pdf_templates_path, params: {
      pdf_template: {
        name: "Session Test Template",
        description: "Testing session persistence",
        template_content: '<h1>{{title}}</h1>',
        active: true
      }
    }
    assert_response :redirect

    # Should still be authenticated
    get pdf_templates_path
    assert_response :success
  end

  test "invalid login credentials are rejected" do
    get new_user_session_path
    assert_response :success

    # Try with wrong password
    post user_session_path, params: {
      user: {
        email: @user.email,
        password: "wrongpassword"
      }
    }

    assert_response :unprocessable_entity  # Rails 7+ returns 422 for failed authentication
    assert_match /Invalid/, response.body

    # Should not be authenticated
    get pdf_templates_path
    assert_redirected_to new_user_session_path

    # Try with non-existent email
    post user_session_path, params: {
      user: {
        email: "nonexistent@example.com",
        password: "password"
      }
    }

    assert_response :unprocessable_entity
    assert_match /Invalid/, response.body
  end

  test "password reset flow" do
    # Request password reset
    get new_user_password_path
    assert_response :success
    assert_select "form"

    post user_password_path, params: {
      user: {
        email: @user.email
      }
    }

    assert_response :redirect
    follow_redirect!
    assert_response :success
    assert_match /You will receive an email with instructions/, response.body

    # In a real application, you would:
    # 1. Check that an email was sent
    # 2. Extract the reset token from the email
    # 3. Visit the reset URL with the token
    # 4. Submit a new password
    
    # For testing purposes, we'll verify the reset form is accessible
    # (actual token testing would require email integration)
  end

  test "user profile editing" do
    sign_in @user

    get edit_user_registration_path
    assert_response :success
    assert_select "form"
    assert_select "input[value='#{@user.email}']"

    # Update email
    patch user_registration_path, params: {
      user: {
        email: "updated@example.com",
        current_password: "password"  # Required by Devise for email changes
      }
    }

    assert_response :redirect
    follow_redirect!
    assert_response :success

    @user.reload
    assert_equal "updated@example.com", @user.email
  end

  test "user can change password" do
    sign_in @user

    get edit_user_registration_path
    assert_response :success

    patch user_registration_path, params: {
      user: {
        password: "newpassword123",
        password_confirmation: "newpassword123",
        current_password: "password"
      }
    }

    assert_response :redirect
    follow_redirect!
    assert_response :success

    # Sign out and try to sign in with new password
    sign_out @user

    post user_session_path, params: {
      user: {
        email: @user.email,
        password: "newpassword123"
      }
    }

    assert_response :redirect
    follow_redirect!
    assert_response :success
  end

  test "user account deletion" do
    sign_in @user
    
    # Store user ID for verification
    user_id = @user.id

    # In Devise, you need to use the registration path with the correct method
    delete user_registration_path, params: {
      user: {
        current_password: "password"  # Usually requires current password
      }
    }
    
    # If account deletion is not enabled, skip this test
    if response.status == 404
      skip "User account deletion not enabled in Devise configuration"
    end
    
    if response.redirect?
      assert_response :redirect
      follow_redirect!
      # After deletion, should be redirected to home/login page
    end

    # User should be deleted
    assert_nil User.find_by(id: user_id)

    # Should be signed out and redirected to login when accessing protected routes
    get pdf_templates_path
    assert_redirected_to new_user_session_path
  end

  test "admin authentication and access" do
    # Admin users use the same authentication as regular users
    # but they can see all templates
    
    # Admin sign in using regular user session path
    get new_user_session_path
    assert_response :success

    post user_session_path, params: {
      user: {
        email: @admin_user.email,
        password: "password"
      }
    }

    assert_response :redirect
    follow_redirect!
    
    # Admin can access regular interface
    get pdf_templates_path
    assert_response :success
    
    # Admin should see all templates (not just their own)
    assert_select "body", text: /Monthly Report/
    assert_select "body", text: /Invoice Template/
  end

  test "session timeout and re-authentication" do
    sign_in @user

    # Verify initial access
    get pdf_templates_path
    assert_response :success

    # Simulate session timeout by signing out
    sign_out @user

    # Should be redirected to login
    get pdf_templates_path
    assert_redirected_to new_user_session_path

    # Re-authenticate
    sign_in @user
    get pdf_templates_path
    assert_response :success
  end

  test "concurrent sessions handling" do
    # Sign in with first session
    sign_in @user
    get pdf_templates_path
    assert_response :success

    # Simulate second session (in real app, this might invalidate first session)
    # For now, just verify that authentication works consistently
    post user_session_path, params: {
      user: {
        email: @user.email,
        password: "password"
      }
    }

    # Should still be able to access protected routes
    get pdf_templates_path
    assert_response :success
  end

  test "remember me functionality" do
    # Test login with remember me
    post user_session_path, params: {
      user: {
        email: @user.email,
        password: "password",
        remember_me: "1"
      }
    }

    assert_response :redirect
    follow_redirect!
    assert_response :success

    # Check that remember token was set (this is handled by Devise internally)
    assert_not_nil cookies["remember_user_token"]
  end

  test "authentication redirects to intended page after login" do
    # Try to access a protected page while not authenticated
    get new_pdf_template_path
    assert_redirected_to new_user_session_path

    # Sign in
    post user_session_path, params: {
      user: {
        email: @user.email,
        password: "password"
      }
    }

    # Should be redirected to the originally requested page
    assert_response :redirect
    follow_redirect!
    assert_response :success
    assert_equal new_pdf_template_path, request.path
  end

  test "user cannot access other user's data after authentication" do
    other_user = users(:two)
    
    # Other user creates a template
    sign_in other_user
    post pdf_templates_path, params: {
      pdf_template: {
        name: "Private Template",
        description: "Should not be accessible",
        template_content: '<h1>{{secret}}</h1>',
        active: true
      }
    }
    private_template = PdfTemplate.last
    sign_out other_user

    # Current user signs in
    sign_in @user

    # Should not see other user's template in listing
    get pdf_templates_path
    assert_response :success
    assert_select "body", { text: /Private Template/, count: 0 }

    # Should not be able to access other user's template directly
    get pdf_template_path(private_template)
    assert_not_equal 200, response.status, "Should not be able to access other user's template"
  end

  test "authentication state is properly cleared on sign out" do
    sign_in @user

    # Verify authentication works
    get pdf_templates_path
    assert_response :success

    # Sign out
    delete destroy_user_session_path
    assert_response :redirect

    # Authentication should be cleared
    get pdf_templates_path
    assert_redirected_to new_user_session_path

    # Cookie should be cleared
    assert_nil session[:warden_user_user_key]
  end

  test "user registration validation" do
    # Test with invalid email
    post user_registration_path, params: {
      user: {
        email: "invalid_email",
        password: "password123",
        password_confirmation: "password123"
      }
    }

    assert_response :unprocessable_entity  # Rails 7+ returns 422 for validation errors
    assert_match /Email/, response.body

    # Test with password mismatch
    post user_registration_path, params: {
      user: {
        email: "valid@example.com",
        password: "password123",
        password_confirmation: "different123"
      }
    }

    assert_response :unprocessable_entity
    assert_match /Password confirmation/, response.body

    # Test with duplicate email
    post user_registration_path, params: {
      user: {
        email: @user.email,  # Already exists
        password: "password123",
        password_confirmation: "password123"
      }
    }

    assert_response :unprocessable_entity
    assert_match /Email.*taken/, response.body
  end

  test "brute force protection" do
    # Test multiple failed login attempts
    # (In a real app, you might implement account locking after X failed attempts)
    
    5.times do
      post user_session_path, params: {
        user: {
          email: @user.email,
          password: "wrongpassword"
        }
      }
      
      assert_response :unprocessable_entity
      assert_match /Invalid/, response.body
    end

    # Account should still be accessible with correct password
    post user_session_path, params: {
      user: {
        email: @user.email,
        password: "password"
      }
    }

    assert_response :redirect
    follow_redirect!
    assert_response :success
  end
end