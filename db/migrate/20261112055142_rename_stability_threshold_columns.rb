class RenameStabilityThresholdColumns < ActiveRecord::Migration[8.1]
  def change
    rename_column :users, :recovering_after_days, :short_streak_after_days
    rename_column :users, :stable_after_days, :long_streak_after_days
    rename_column :users, :rock_solid_after_days, :solid_streak_after_days
  end
end
