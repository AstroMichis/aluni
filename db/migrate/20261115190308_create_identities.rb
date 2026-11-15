# A provider account (Google, Apple, Microsoft) linked to a user for social
# sign-in. Identity only: no OAuth tokens are kept, Aluni never calls the
# provider's APIs on the person's behalf.
class CreateIdentities < ActiveRecord::Migration[8.1]
  def change
    create_table :identities do |t|
      t.references :user, null: false, foreign_key: true, index: false
      t.string :provider, null: false
      t.string :uid, null: false
      t.string :email
      t.boolean :email_verified, null: false, default: false
      t.string :name
      t.datetime :last_used_at

      t.timestamps
    end
    add_index :identities, %i[provider uid], unique: true
    # One account per provider per person.
    add_index :identities, %i[user_id provider], unique: true
  end
end
