ActiveAdmin.register ProcessedPdf do
  permit_params :pdf_template_id, :original_html, :variables_used, :metadata

  index do
    selectable_column
    id_column
    column :pdf_template
    column :generated_at
    column :pdf_file do |pdf|
      if pdf.pdf_file.attached?
        link_to "Download", rails_blob_path(pdf.pdf_file, disposition: "attachment")
      else
        "No file"
      end
    end
    column :created_at
    actions
  end

  filter :pdf_template
  filter :generated_at
  filter :created_at

  show do
    attributes_table do
      row :id
      row :pdf_template
      row :generated_at
      row :created_at
      row :updated_at
    end
    
    panel "Variables Used" do
      attributes_table_for processed_pdf do
        processed_pdf.variables_used.each do |key, value|
          row key do
            value
          end
        end
      end
    end
    
    panel "PDF File" do
      if processed_pdf.pdf_file.attached?
        div do
          link_to "Download PDF", rails_blob_path(processed_pdf.pdf_file, disposition: "attachment"), 
                  class: "button"
        end
      else
        "No file attached"
      end
    end
    
    panel "Original HTML" do
      div do
        simple_format processed_pdf.original_html
      end
    end
    
    if processed_pdf.metadata.present?
      panel "Metadata" do
        pre do
          JSON.pretty_generate(processed_pdf.metadata)
        end
      end
    end
  end
end