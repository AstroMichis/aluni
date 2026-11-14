class CreateWebPushSubscriptions < ActiveRecord::Migration[8.1]
  def change
    # A browser that agreed to notifications (Web Push, VAPID), one row per
    # account and browser endpoint.
    create_table :web_push_subscriptions do |t|
      t.references :user, null: false, foreign_key: true
      t.text :endpoint, null: false
      t.string :p256dh, null: false
      t.string :auth, null: false
      t.string :user_agent
      t.datetime :last_used_at

      t.timestamps
    end
    add_index :web_push_subscriptions, [ :user_id, :endpoint ], unique: true
  end
end
