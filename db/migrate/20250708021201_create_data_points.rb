class CreateDataPoints < ActiveRecord::Migration[8.0]
  def change
    create_table :data_points do |t|
      t.references :data_source, null: false, foreign_key: true
      t.string :key, null: false
      t.json :value, null: false
      t.datetime :fetched_at, null: false
      t.datetime :expires_at
      t.json :metadata, default: {}

      t.timestamps
    end
    
    add_index :data_points, [:data_source_id, :key]
    add_index :data_points, :expires_at
    add_index :data_points, :fetched_at
  end
end
