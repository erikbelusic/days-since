class CreateSubscriptions < ActiveRecord::Migration[8.1]
  def change
    create_table :subscriptions do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.references :feed, null: false, foreign_key: true
      t.string :display_name
      t.string :min_severity
      t.integer :position, null: false, default: 0

      t.timestamps
    end
    add_index :subscriptions, [ :user_id, :feed_id ], unique: true
    add_index :subscriptions, [ :user_id, :position ]
  end
end
