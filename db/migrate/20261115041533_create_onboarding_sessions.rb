class CreateOnboardingSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :onboarding_sessions do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.string :topic, null: false, default: "welcome"
      t.integer :status, null: false, default: 0
      t.datetime :completed_at
      t.text :transcript
      t.jsonb :proposal, null: false, default: {}
      t.text :pending_message
      t.integer :fallbacks_count, null: false, default: 0
      t.integer :turns_count, null: false, default: 0
      t.integer :strikes, null: false, default: 0
      t.datetime :blocked_until
      t.string :language
      t.datetime :last_message_at

      t.timestamps
    end
  end
end
