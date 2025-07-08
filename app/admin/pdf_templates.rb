ActiveAdmin.register PdfTemplate do
  permit_params :name, :description, :template_content, :active, :user_id

  index do
    selectable_column
    id_column
    column :name
    column :user
    column :active
    column :processed_pdfs_count do |template|
      template.processed_pdfs.count
    end
    column :created_at
    actions
  end

  filter :name
  filter :user
  filter :active
  filter :created_at

  form do |f|
    f.inputs do
      f.input :name
      f.input :user
      f.input :description
      f.input :template_content, as: :text, input_html: { rows: 20 }
      f.input :active
    end
    f.actions
  end

  show do
    attributes_table do
      row :id
      row :name
      row :user
      row :description
      row :active
      row :created_at
      row :updated_at
    end
    
    panel "Template Content" do
      div do
        simple_format pdf_template.template_content
      end
    end
    
    panel "Template Variables" do
      ul do
        pdf_template.variable_names.each do |variable|
          li "{{#{variable}}}"
        end
      end
    end
    
    panel "Recent Processed PDFs" do
      table_for pdf_template.processed_pdfs.recent.limit(10) do
        column :id do |pdf|
          link_to pdf.id, admin_processed_pdf_path(pdf)
        end
        column :generated_at
        column :variables_used do |pdf|
          pdf.variables_used.to_json
        end
      end
    end
  end
end