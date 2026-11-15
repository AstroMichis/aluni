class CreateSignInCodes < ActiveRecord::Migration[8.1]
  def change
    create_table :sign_in_codes do |t|
      t.integer :channel, null: false, default: 0
      t.string :destination, null: false
      t.string :code_digest, null: false
      t.datetime :expires_at, null: false
      t.integer :attempts, null: false, default: 0
      t.datetime :consumed_at
      t.datetime :verified_at
      t.datetime :used_at
      t.string :requester_ip
      t.string :locale, null: false, default: "en"
      t.jsonb :pending, null: false, default: {}

      t.timestamps
    end
    add_index :sign_in_codes, [ :destination, :created_at ]
  end
end
