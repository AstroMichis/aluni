class CreatePasskeys < ActiveRecord::Migration[8.1]
  def change
    # One row per registered WebAuthn credential. external_id is the credential
    # id (base64url), public_key the COSE key (base64url) the webauthn gem
    # verifies assertions against; sign_count is the authenticator counter.
    create_table :passkeys do |t|
      t.references :user, null: false, foreign_key: true
      t.string :external_id, null: false
      t.text :public_key, null: false
      t.bigint :sign_count, null: false, default: 0
      t.string :nickname, null: false, default: ""
      t.string :transports, array: true, null: false, default: []
      t.datetime :last_used_at

      t.timestamps
    end
    add_index :passkeys, :external_id, unique: true
  end
end
