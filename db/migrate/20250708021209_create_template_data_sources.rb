class CreateTemplateDataSources < ActiveRecord::Migration[8.0]
  def change
    create_table :template_data_sources do |t|
      t.references :pdf_template, null: false, foreign_key: true
      t.references :data_source, null: false, foreign_key: true
      t.boolean :enabled, default: true, null: false

      t.timestamps
    end
    
    add_index :template_data_sources, [:pdf_template_id, :data_source_id], 
              unique: true, name: 'index_template_data_sources_unique'
  end
end
