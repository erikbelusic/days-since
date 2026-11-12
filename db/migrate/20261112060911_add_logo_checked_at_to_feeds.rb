class AddLogoCheckedAtToFeeds < ActiveRecord::Migration[8.1]
  def change
    add_column :feeds, :logo_checked_at, :datetime
  end
end
