class AddUserToPdfTemplates < ActiveRecord::Migration[8.0]
  def change
    add_reference :pdf_templates, :user, null: false, foreign_key: true
  end
end
