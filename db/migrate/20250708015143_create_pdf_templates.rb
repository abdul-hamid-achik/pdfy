class CreatePdfTemplates < ActiveRecord::Migration[8.0]
  def change
    create_table :pdf_templates do |t|
      t.string :name, null: false
      t.text :description
      t.text :template_content, null: false
      t.json :template_variables, default: {}
      t.boolean :active, default: true, null: false

      t.timestamps
    end
    
    add_index :pdf_templates, :name, unique: true
    add_index :pdf_templates, :active
  end
end
