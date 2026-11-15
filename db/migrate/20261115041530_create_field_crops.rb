class CreateFieldCrops < ActiveRecord::Migration[8.1]
  def change
    create_table :field_crops do |t|
      t.references :field, null: false, foreign_key: true
      t.string :crop_name, null: false
      t.string :scientific_name
      t.string :crop_key
      t.integer :season_year, null: false
      t.integer :planting_month
      t.integer :harvest_month
      t.integer :role, null: false, default: 0
      t.integer :source, null: false, default: 0
      t.string :notes

      t.timestamps
    end
    add_index :field_crops, [ :field_id, :season_year, :role ], unique: true
  end
end
