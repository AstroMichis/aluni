# One-use tokens that carry a finished social sign-in from the system browser
# (ASWebAuthenticationSession, Custom Tabs) back into a native shell's web view,
# which does not share the browser's cookies. Two minutes, then purged daily.
class CreateAuthHandoffs < ActiveRecord::Migration[8.1]
  def change
    create_table :auth_handoffs do |t|
      t.references :user, null: false, foreign_key: true
      t.string :token_digest, null: false
      t.string :sign_in_method, null: false
      t.datetime :expires_at, null: false
      t.datetime :used_at

      t.timestamps
    end
    add_index :auth_handoffs, :token_digest, unique: true
  end
end
