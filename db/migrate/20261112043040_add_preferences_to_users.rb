class AddPreferencesToUsers < ActiveRecord::Migration[8.1]
  def change
    change_table :users, bulk: true do |t|
      t.string :time_zone, null: false, default: "UTC"
      t.string :default_min_severity, null: false, default: "minor"
      t.string :no_incident_display, null: false, default: "infinity"
    end
  end
end
