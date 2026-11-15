class AddLastAppliedToOnboardingSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :onboarding_sessions, :last_applied, :jsonb, null: false, default: {}
  end
end
