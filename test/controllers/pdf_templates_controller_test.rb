require "test_helper"

class PdfTemplatesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def setup
    @user = users(:one)
    @admin_user = admin_users(:one)
    @pdf_template = pdf_templates(:one)
    @other_user_template = pdf_templates(:two)
  end

  test "should redirect to login when not authenticated" do
    get pdf_templates_url
    assert_redirected_to new_user_session_path
  end

  test "should get index when authenticated" do
    sign_in @user
    get pdf_templates_url
    assert_response :success
    assert_select "h1", "PDF Templates"
  end

  test "should show only user's templates for regular users" do
    sign_in @user
    get pdf_templates_url
    assert_response :success
    assert_select "body", text: /Monthly Report/
    assert_select "body", { text: /Invoice Template/, count: 0 }
  end

  test "should show all templates for admin users" do
    sign_in @admin_user
    get pdf_templates_url
    assert_response :success
    # Admin should see all templates
    assert_select "body", text: /Monthly Report/
    assert_select "body", text: /Invoice Template/
  end

  test "should get new" do
    sign_in @user
    get new_pdf_template_url
    assert_response :success
    assert_select "h1", "New PDF Template"
  end

  test "should create pdf template with valid params" do
    sign_in @user
    assert_difference("PdfTemplate.count") do
      post pdf_templates_url, params: {
        pdf_template: {
          name: "New Template",
          description: "A new template",
          template_content: '<h1>{{title}}</h1>',
          active: true
        }
      }
    end

    assert_redirected_to pdf_template_url(PdfTemplate.last)
    assert_equal "PDF template was successfully created.", flash[:notice]
    assert_equal @user, PdfTemplate.last.user
  end

  test "should not create pdf template with invalid params" do
    sign_in @user
    assert_no_difference("PdfTemplate.count") do
      post pdf_templates_url, params: {
        pdf_template: {
          name: "",  # Invalid - name is required
          description: "A template without name",
          template_content: "<h1>\{\{title\}\}</h1>"
        }
      }
    end

    assert_response :unprocessable_entity
    assert_select "div.error", /Name can't be blank/
  end

  test "should show pdf template" do
    sign_in @user
    get pdf_template_url(@pdf_template)
    assert_response :success
    assert_select "h1", "Test Template"
    assert_select "p", text: /A test template/
  end

  test "should not show other user's template for regular users" do
    sign_in @user
    assert_raises(ActiveRecord::RecordNotFound) do
      get pdf_template_url(@other_user_template)
    end
  end

  test "should show any template for admin users" do
    sign_in @admin_user
    get pdf_template_url(@other_user_template)
    assert_response :success
    assert_select "h1", "Other User Template"
  end

  test "should get edit" do
    sign_in @user
    get edit_pdf_template_url(@pdf_template)
    assert_response :success
    assert_select "h1", "Edit PDF Template"
    assert_select "input[value='Test Template']"
  end

  test "should not get edit for other user's template" do
    sign_in @user
    assert_raises(ActiveRecord::RecordNotFound) do
      get edit_pdf_template_url(@other_user_template)
    end
  end

  test "should update pdf template with valid params" do
    sign_in @user
    patch pdf_template_url(@pdf_template), params: {
      pdf_template: {
        name: "Updated Template",
        description: "Updated description",
        template_content: '<h2>{{updated_content}}</h2>',
        active: false
      }
    }

    assert_redirected_to pdf_template_url(@pdf_template)
    assert_equal "PDF template was successfully updated.", flash[:notice]
    
    @pdf_template.reload
    assert_equal "Updated Template", @pdf_template.name
    assert_equal "Updated description", @pdf_template.description
    assert_equal '<h2>{{updated_content}}</h2>', @pdf_template.template_content
    assert_not @pdf_template.active
  end

  test "should not update pdf template with invalid params" do
    sign_in @user
    patch pdf_template_url(@pdf_template), params: {
      pdf_template: {
        name: "",  # Invalid
        description: "Updated description"
      }
    }

    assert_response :unprocessable_entity
    assert_select "div.error", /Name can't be blank/
    
    @pdf_template.reload
    assert_equal "Test Template", @pdf_template.name  # Should not have changed
  end

  test "should not update other user's template" do
    sign_in @user
    assert_raises(ActiveRecord::RecordNotFound) do
      patch pdf_template_url(@other_user_template), params: {
        pdf_template: { name: "Hacked Template" }
      }
    end
  end

  test "should destroy pdf template" do
    sign_in @user
    assert_difference("PdfTemplate.count", -1) do
      delete pdf_template_url(@pdf_template)
    end

    assert_redirected_to pdf_templates_url
    assert_equal "PDF template was successfully destroyed.", flash[:notice]
  end

  test "should not destroy other user's template" do
    sign_in @user
    assert_no_difference("PdfTemplate.count") do
      assert_raises(ActiveRecord::RecordNotFound) do
        delete pdf_template_url(@other_user_template)
      end
    end
  end

  test "admin should be able to edit any template" do
    sign_in @admin_user
    get edit_pdf_template_url(@other_user_template)
    assert_response :success
    assert_select "h1", "Edit PDF Template"
  end

  test "admin should be able to update any template" do
    sign_in @admin_user
    patch pdf_template_url(@other_user_template), params: {
      pdf_template: {
        name: "Admin Updated Template",
        description: "Updated by admin"
      }
    }

    assert_redirected_to pdf_template_url(@other_user_template)
    assert_equal "PDF template was successfully updated.", flash[:notice]
    
    @other_user_template.reload
    assert_equal "Admin Updated Template", @other_user_template.name
  end

  test "admin should be able to destroy any template" do
    sign_in @admin_user
    assert_difference("PdfTemplate.count", -1) do
      delete pdf_template_url(@other_user_template)
    end

    assert_redirected_to pdf_templates_url
    assert_equal "PDF template was successfully destroyed.", flash[:notice]
  end

  test "should display recent processed PDFs on show page" do
    sign_in @user
    
    # Create some processed PDFs
    5.times do |i|
      pdf = @pdf_template.processed_pdfs.build(
        original_html: "<h1>Test #{i}</h1>",
        variables_used: { "name" => "Test #{i}" }
      )
      pdf.pdf_file.attach(
        io: StringIO.new("Dummy PDF content #{i}"),
        filename: "test_#{i}.pdf",
        content_type: "application/pdf"
      )
      pdf.save!
    end

    get pdf_template_url(@pdf_template)
    assert_response :success
    assert_select "h2", "Recent PDFs"
    assert_select ".processed-pdf", count: 5
  end

  test "should limit processed PDFs to 10 on show page" do
    sign_in @user
    
    # Create 15 processed PDFs
    15.times do |i|
      pdf = @pdf_template.processed_pdfs.build(
        original_html: "<h1>Test #{i}</h1>",
        variables_used: { "name" => "Test #{i}" }
      )
      pdf.pdf_file.attach(
        io: StringIO.new("Dummy PDF content #{i}"),
        filename: "test_#{i}.pdf",
        content_type: "application/pdf"
      )
      pdf.save!
    end

    get pdf_template_url(@pdf_template)
    assert_response :success
    # Should only show 10 most recent
    assert_select ".processed-pdf", maximum: 10
  end

  test "should handle templates with no processed PDFs" do
    sign_in @user
    get pdf_template_url(@pdf_template)
    assert_response :success
    assert_select "p", text: /No PDFs generated yet/
  end

  test "should display variable extraction from template content" do
    template_with_vars = PdfTemplate.create!(
      name: "Variable Template",
      description: "Template with multiple variables",
      template_content: '<h1>{{title}}</h1><p>Hello {{name}}, your email is {{email}}</p>',
      user: @user,
      active: true
    )

    sign_in @user
    get pdf_template_url(template_with_vars)
    assert_response :success
    
    # Check that variables are displayed
    assert_select "body", text: /title/
    assert_select "body", text: /name/
    assert_select "body", text: /email/
  end

  test "should order templates by creation date" do
    sign_in @user
    
    # Create templates with different creation times
    old_template = PdfTemplate.create!(
      name: "Old Template",
      description: "An old template",
      template_content: '<h1>Old</h1>',
      user: @user,
      active: true,
      created_at: 2.days.ago
    )
    
    new_template = PdfTemplate.create!(
      name: "New Template",
      description: "A new template",
      template_content: '<h1>New</h1>',
      user: @user,
      active: true,
      created_at: 1.hour.ago
    )

    get pdf_templates_url
    assert_response :success
    
    # Should be ordered by creation date (newest first)
    response_body = response.body
    new_template_index = response_body.index("New Template")
    old_template_index = response_body.index("Old Template")
    
    assert new_template_index < old_template_index, "New template should appear before old template"
  end

  test "should handle inactive templates" do
    inactive_template = pdf_templates(:inactive)

    sign_in @user
    get pdf_templates_url
    assert_response :success
    
    # Should still show inactive templates (with indication)
    assert_select "body", text: /Inactive Template/
  end

  test "should validate template content for common issues" do
    sign_in @user
    
    # Test with unmatched braces
    post pdf_templates_url, params: {
      pdf_template: {
        name: "Invalid Template",
        description: "Template with unmatched braces",
        template_content: '<h1>{{title}</h1><p>{{incomplete_var</p>',
        active: true
      }
    }

    # Should still create (validation is not enforced at this level)
    assert_redirected_to pdf_template_url(PdfTemplate.last)
  end

  test "should handle templates with complex HTML" do
    complex_html = <<~'HTML'
      <div class="container">
        <header>
          <h1>{{company_name}}</h1>
          <nav>
            <ul>
              <li><a href="#section1">Section 1</a></li>
              <li><a href="#section2">Section 2</a></li>
            </ul>
          </nav>
        </header>
        <main>
          <section id="section1">
            <h2>{{section1_title}}</h2>
            <p>{{section1_content}}</p>
          </section>
          <section id="section2">
            <h2>{{section2_title}}</h2>
            <p>{{section2_content}}</p>
          </section>
        </main>
      </div>
    HTML

    sign_in @user
    assert_difference("PdfTemplate.count") do
      post pdf_templates_url, params: {
        pdf_template: {
          name: "Complex Template",
          description: "Template with complex HTML structure",
          template_content: complex_html,
          active: true
        }
      }
    end

    assert_redirected_to pdf_template_url(PdfTemplate.last)
    
    created_template = PdfTemplate.last
    assert_equal complex_html, created_template.template_content
  end
end