class CreateFarms < ActiveRecord::Migration[8.1]
  def change
    create_table :farms do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false, default: ""
      t.string :country_code, limit: 2
      t.string :admin_area

      t.timestamps
    end
  end
end
