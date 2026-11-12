class AddStabilityThresholdsToUsers < ActiveRecord::Migration[8.1]
  def change
    change_table :users, bulk: true do |t|
      t.integer :recovering_after_days, null: false, default: 7
      t.integer :stable_after_days, null: false, default: 30
      t.integer :rock_solid_after_days, null: false, default: 90
    end
  end
end
