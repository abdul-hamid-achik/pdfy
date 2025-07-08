ActiveAdmin.register User do
  permit_params :email, :password, :password_confirmation, :admin

  index do
    selectable_column
    id_column
    column :email
    column :admin
    column :pdf_templates_count do |user|
      user.pdf_templates.count
    end
    column :processed_pdfs_count do |user|
      user.processed_pdfs.count
    end
    column :created_at
    actions
  end

  filter :email
  filter :admin
  filter :created_at

  form do |f|
    f.inputs do
      f.input :email
      f.input :password
      f.input :password_confirmation
      f.input :admin
    end
    f.actions
  end

  show do
    attributes_table do
      row :id
      row :email
      row :admin
      row :created_at
      row :updated_at
    end
    
    panel "PDF Templates" do
      table_for user.pdf_templates do
        column :name do |template|
          link_to template.name, admin_pdf_template_path(template)
        end
        column :active
        column :created_at
      end
    end
  end
end