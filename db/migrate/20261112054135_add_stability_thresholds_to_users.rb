class AddStabilityThresholdsToUsers < ActiveRecord::Migration[8.1]
  def change
    change_table :users, bulk: true do |t|
      t.integer :short_streak_after_days, null: false, default: 7
      t.integer :long_streak_after_days, null: false, default: 30
      t.integer :solid_streak_after_days, null: false, default: 90
    end
  end
end
