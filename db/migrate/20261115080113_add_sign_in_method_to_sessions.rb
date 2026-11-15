class AddSignInMethodToSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :sessions, :sign_in_method, :string, null: false, default: "passkey"
  end
end
