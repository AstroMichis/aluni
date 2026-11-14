class CreatePlatformSwitches < ActiveRecord::Migration[8.1]
  def change
    # One row per paused (or once-paused) outside service (PlatformSwitch::SERVICES).
    create_table :platform_switches do |t|
      t.string :service, null: false
      t.boolean :paused, null: false, default: false
      t.string :paused_by
      t.string :reason

      t.timestamps
    end
    add_index :platform_switches, :service, unique: true
  end
end
