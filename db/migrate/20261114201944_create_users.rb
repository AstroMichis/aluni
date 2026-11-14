class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    # Passkey-only accounts: no password, no required email. webauthn_id is the
    # opaque WebAuthn user handle (WebAuthn.generate_user_id) authenticators
    # return with a discoverable credential.
    create_table :users do |t|
      t.string :webauthn_id, null: false
      t.string :display_name, null: false
      t.string :email_address
      t.string :locale, null: false, default: "en"

      t.timestamps
    end
    add_index :users, :webauthn_id, unique: true
    add_index :users, :email_address, unique: true, where: "email_address IS NOT NULL"
  end
end
