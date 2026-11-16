# What the farmer harvested and earned from one crop in one season: the
# farmer's own yields (docs/proposal V3: FAO GAEZ ran 20-99 % above real
# yields) and the margin the rotation comparison shows, never scores (V7).
class AddHarvestToFieldCrops < ActiveRecord::Migration[8.1]
  def change
    change_table :field_crops, bulk: true do |t|
      t.decimal :yield_amount, precision: 12, scale: 2
      t.string :yield_unit
      t.string :area_basis
      t.decimal :price, precision: 12, scale: 2
      t.decimal :cost, precision: 12, scale: 2
      t.string :currency, limit: 3
    end
  end
end
