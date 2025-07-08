class CreateDataSources < ActiveRecord::Migration[8.0]
  def change
    create_table :data_sources do |t|
      t.string :name, null: false
      t.string :source_type, null: false
      t.string :api_endpoint, null: false
      t.string :api_key
      t.json :configuration, default: {}
      t.boolean :active, default: true, null: false
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
    
    add_index :data_sources, [:user_id, :name], unique: true
    add_index :data_sources, :source_type
    add_index :data_sources, :active
  end
end
