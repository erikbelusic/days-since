class AddDashboardLayoutToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :dashboard_layout, :string, null: false, default: "cards"
  end
end
