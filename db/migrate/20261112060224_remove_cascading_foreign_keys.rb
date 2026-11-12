# Deletes are handled by Rails (dependent: :destroy / :delete_all), never by
# the database. Keep the foreign keys for integrity, drop ON DELETE CASCADE.
# On SQLite this rebuilds subscriptions and incidents; nothing references
# those tables, so the rebuild can't cascade anywhere.
class RemoveCascadingForeignKeys < ActiveRecord::Migration[8.1]
  def change
    remove_foreign_key :subscriptions, :users, on_delete: :cascade
    add_foreign_key :subscriptions, :users

    remove_foreign_key :incidents, :feeds, on_delete: :cascade
    add_foreign_key :incidents, :feeds
  end
end
