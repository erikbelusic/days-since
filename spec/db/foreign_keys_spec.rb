require "rails_helper"

# Deletes are Rails' job (dependent: :destroy / :delete_all); the database
# only guards integrity. Cascading foreign keys also turn SQLite table
# rebuilds into silent mass deletes, so none are allowed (see CLAUDE.md).
RSpec.describe "Foreign keys" do
  let(:connection) { ActiveRecord::Base.connection }

  it "never cascade or nullify on delete" do
    cascading = connection.tables.flat_map do |table|
      connection.foreign_keys(table).select(&:on_delete).map { |fk| "#{table}.#{fk.column} (on_delete: #{fk.on_delete})" }
    end

    expect(cascading).to be_empty
  end

  it "still protect integrity" do
    user = create(:user)
    create(:subscription, user: user)

    expect { user.delete }.to raise_error(ActiveRecord::InvalidForeignKey)
  end

  it "leave cleanup to Rails associations" do
    user = create(:user)
    create(:subscription, user: user)
    feed = create(:incident).feed

    expect { user.destroy }.to change(Subscription, :count).by(-1)
    expect { feed.destroy }.to change(Incident, :count).by(-1)
  end
end
