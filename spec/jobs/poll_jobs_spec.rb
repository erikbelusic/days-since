require "rails_helper"

RSpec.describe "Feed polling jobs" do
  describe PollDueFeedsJob do
    it "enqueues a poll for each due feed only" do
      due = create(:subscription).feed
      create(:subscription, feed: create(:feed, next_poll_at: 1.hour.from_now))
      create(:feed)

      expect { described_class.perform_now }
        .to have_enqueued_job(PollFeedJob).with(due).exactly(:once)
        .and have_enqueued_job(PollFeedJob).exactly(:once)
    end

    it "is scheduled every 5 minutes" do
      schedule = ActiveSupport::ConfigurationFile.parse(Rails.root.join("config/recurring.yml"))

      expect(schedule.dig("production", "poll_due_feeds")).to include("class" => "PollDueFeedsJob", "schedule" => "every 5 minutes")
      expect(schedule.dig("development", "poll_due_feeds")).to be_present
    end
  end

  describe PollFeedJob do
    it "polls a subscribed feed" do
      feed = create(:subscription).feed
      stub_request(:get, feed.url).to_return(status: 200, body: file_fixture("statuspage/incidents.json").read)

      described_class.perform_now(feed)

      expect(feed.incidents.count).to eq(4)
    end

    it "skips a feed nobody subscribes to" do
      feed = create(:feed)

      described_class.perform_now(feed)

      expect(feed.reload.last_polled_at).to be_nil
    end
  end
end

RSpec.describe "Feed logo jobs" do
  describe RefreshFeedLogosJob do
    it "queues a logo check for subscribed feeds never checked or checked over a week ago" do
      now = Time.utc(2026, 3, 10)
      never = create(:subscription, feed: create(:feed, logo_checked_at: nil)).feed
      stale = create(:subscription, feed: create(:feed, logo_checked_at: now - 8.days)).feed
      create(:subscription, feed: create(:feed, logo_checked_at: now - 1.day))
      create(:feed, logo_checked_at: nil) # nobody subscribes

      expect { described_class.perform_now(now: now) }
        .to have_enqueued_job(FetchFeedLogoJob).with(never)
        .and have_enqueued_job(FetchFeedLogoJob).with(stale)
        .and have_enqueued_job(FetchFeedLogoJob).exactly(2).times
    end

    it "runs daily" do
      schedule = ActiveSupport::ConfigurationFile.parse(Rails.root.join("config/recurring.yml"))

      expect(schedule.dig("production", "refresh_feed_logos")).to include("class" => "RefreshFeedLogosJob")
    end
  end

  describe FetchFeedLogoJob do
    it "skips feeds nobody subscribes to" do
      feed = create(:feed)

      described_class.perform_now(feed)

      expect(feed.reload.logo_checked_at).to be_nil
    end
  end
end
