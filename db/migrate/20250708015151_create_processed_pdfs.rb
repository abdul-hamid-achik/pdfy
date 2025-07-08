class CreateProcessedPdfs < ActiveRecord::Migration[8.0]
  def change
    create_table :processed_pdfs do |t|
      t.references :pdf_template, null: false, foreign_key: true
      t.text :original_html, null: false
      t.json :variables_used, default: {}
      t.datetime :generated_at, null: false
      t.json :metadata, default: {}

      t.timestamps
    end
    
    add_index :processed_pdfs, :generated_at
  end
end
