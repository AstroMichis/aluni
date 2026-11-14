class CreateNotificationDeliveries < ActiveRecord::Migration[8.1]
  def change
    # One row per NotificationRouter.deliver call, keyed by idempotency_key so
    # the same message is never sent twice; attempts records what each channel did.
    create_table :notification_deliveries do |t|
      t.string :purpose, null: false
      t.references :recipient, polymorphic: true, null: false
      t.string :idempotency_key, null: false
      t.integer :status, null: false, default: 0
      t.string :channel
      t.datetime :sent_at
      t.string :provider_message_id
      t.jsonb :attempts, null: false, default: []
      t.string :failed_reason

      t.timestamps
    end
    add_index :notification_deliveries, :idempotency_key, unique: true
    add_index :notification_deliveries, [ :purpose, :created_at ]
  end
end
