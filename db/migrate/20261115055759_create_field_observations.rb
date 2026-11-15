# What the public data sources returned for one field's pin: one row per
# source (nasa_power, gaez, ssurgo, usgs_elevation, cdl, fcc), replaced on
# every fetch. Written only by Fields::FetchObservationsJob.
class CreateFieldObservations < ActiveRecord::Migration[8.1]
  def change
    create_table :field_observations do |t|
      t.references :field, null: false, foreign_key: true
      t.string :source, null: false
      t.integer :status, null: false, default: 0
      t.jsonb :payload, null: false, default: {}
      t.string :error
      t.datetime :fetched_at
      t.timestamps
    end
    add_index :field_observations, %i[field_id source], unique: true
  end
end
