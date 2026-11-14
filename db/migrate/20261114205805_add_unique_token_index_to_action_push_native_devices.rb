class AddUniqueTokenIndexToActionPushNativeDevices < ActiveRecord::Migration[8.1]
  def change
    # Notifications::PushDevices upserts by (platform, token) and relies on this index.
    add_index :action_push_native_devices, [ :platform, :token ], unique: true, if_not_exists: true
  end
end
