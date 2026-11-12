class CreateIncidents < ActiveRecord::Migration[8.1]
  def change
    create_table :incidents do |t|
      t.references :feed, null: false, foreign_key: { on_delete: :cascade }
      t.string :external_id, null: false
      t.string :title, null: false
      t.string :impact, null: false, default: "unknown"
      t.string :status
      t.string :url
      t.datetime :started_at, null: false
      t.datetime :resolved_at

      t.timestamps
    end
    add_index :incidents, [ :feed_id, :external_id ], unique: true
    add_index :incidents, [ :feed_id, :started_at ]
  end
end
