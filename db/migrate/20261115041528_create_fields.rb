class CreateFields < ActiveRecord::Migration[8.1]
  def change
    create_table :fields do |t|
      t.references :farm, null: false, foreign_key: true
      t.string :name, null: false, default: ""
      t.integer :position, null: false, default: 0
      t.decimal :latitude, precision: 9, scale: 6
      t.decimal :longitude, precision: 9, scale: 6
      t.integer :location_confidence, null: false, default: 0
      t.integer :location_source, null: false, default: 0
      t.string :place_label
      t.jsonb :boundary, null: false, default: {}
      t.decimal :area, precision: 10, scale: 2
      t.integer :area_unit, null: false, default: 0
      t.integer :irrigation, null: false, default: 0
      t.integer :water_source, null: false, default: 0
      t.integer :cropping_intensity, null: false, default: 0
      t.jsonb :soil, null: false, default: {}

      t.timestamps
    end
    add_index :fields, [ :farm_id, :position ]
  end
end
