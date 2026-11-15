class CreateFarmerProfiles < ActiveRecord::Migration[8.1]
  def change
    create_table :farmer_profiles do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.integer :role, null: false, default: 0
      t.integer :experience, null: false, default: 0
      t.integer :team, null: false, default: 0
      t.integer :team_size
      t.integer :units, null: false, default: 0
      t.integer :land_tenure, null: false, default: 0
      t.integer :budget_level, null: false, default: 0
      t.integer :risk_tolerance, null: false, default: 0
      t.integer :segment, null: false, default: 0
      t.jsonb :goals, null: false, default: []
      t.jsonb :equipment, null: false, default: []
      t.jsonb :livestock, null: false, default: []
      t.jsonb :market_channels, null: false, default: []
      t.jsonb :practices, null: false, default: []
      t.jsonb :notification_preferences, null: false, default: {}
      t.text :notes

      t.timestamps
    end
  end
end
