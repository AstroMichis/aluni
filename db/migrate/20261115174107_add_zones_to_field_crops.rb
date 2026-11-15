# A season can split a field between crops (crop zones): each row keeps the
# share of the field it covers and the cells of the 10x10 field map it sits
# on. No share and no cells means the whole field, as every existing row.
class AddZonesToFieldCrops < ActiveRecord::Migration[8.1]
  def change
    add_column :field_crops, :share, :decimal, precision: 5, scale: 4
    add_column :field_crops, :cells, :integer, array: true, default: [], null: false

    remove_index :field_crops, %i[field_id season_year role], unique: true,
                 name: "index_field_crops_on_field_id_and_season_year_and_role"
    add_index :field_crops, %i[field_id season_year role crop_key], unique: true,
              name: "index_field_crops_on_field_season_role_crop"
  end
end
