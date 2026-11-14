class CreateDeviceTokens < ActiveRecord::Migration[8.1]
  def change
    # Native push tokens registered by the shells (bridge `notification-token`).
    # Mirrored into action_push_native_devices by Notifications::PushDevices.
    create_table :device_tokens do |t|
      t.references :user, null: false, foreign_key: true
      t.string :token, null: false
      t.integer :platform, null: false, default: 0

      t.timestamps
    end
    add_index :device_tokens, [ :token, :platform ], unique: true
  end
end
