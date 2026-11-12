class CreateFeeds < ActiveRecord::Migration[8.1]
  def change
    create_table :feeds do |t|
      t.string :url, null: false
      t.string :provider, null: false
      t.string :name
      t.string :site_url
      t.datetime :last_polled_at
      t.datetime :last_success_at
      t.datetime :next_poll_at
      t.text :last_error
      t.integer :consecutive_failures, null: false, default: 0
      t.string :etag
      t.string :last_modified

      t.timestamps
    end
    add_index :feeds, :url, unique: true
    add_index :feeds, :next_poll_at
  end
end
