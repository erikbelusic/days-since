require "rails_helper"

RSpec.describe "db/seeds.rb" do
  include ActiveJob::TestHelper

  context "in development" do
    before { allow(Rails.env).to receive(:development?).and_return(true) }

    it "subscribes the local user to GitHub, Cloudflare, and Slack and queues first polls" do
      expect { load Rails.root.join("db/seeds.rb") }
        .to output(/Seeded local@days-since.local with 3 status pages/).to_stdout
        .and have_enqueued_job(PollFeedJob).exactly(3).times

      feeds = SingleUserMode.user.subscriptions.ordered.map(&:feed)
      expect(feeds.map(&:name)).to eq(%w[GitHub Cloudflare Slack])
      expect(feeds.map(&:provider)).to eq(%w[statuspage statuspage rss])
    end

    it "does nothing when the local user already has subscriptions" do
      create(:subscription, user: SingleUserMode.user)

      expect { load Rails.root.join("db/seeds.rb") }.not_to change(Subscription, :count)
    end

    it "reuses feeds that already exist" do
      create(:feed, url: "https://www.githubstatus.com/api/v2/incidents.json")

      expect { load Rails.root.join("db/seeds.rb") }.to output.to_stdout.and change(Feed, :count).by(2)
    end
  end

  it "does nothing outside development" do
    expect { load Rails.root.join("db/seeds.rb") }.not_to change(User, :count)
  end
end
