require "rails_helper"

RSpec.describe Feed do
  it "stores its URL normalized" do
    feed = create(:feed, url: "HTTPS://Status.Example.com/api/v2/incidents.json/")

    expect(feed.url).to eq("https://status.example.com/api/v2/incidents.json")
  end

  it "allows only one feed per normalized URL" do
    create(:feed, url: "https://status.example.com/api/v2/incidents.json")
    duplicate = build(:feed, url: "status.example.com/api/v2/incidents.json/")

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:url]).to include("has already been taken")
  end

  it "finds an existing feed by an equivalent URL" do
    feed = create(:feed, url: "https://status.example.com/history.rss", provider: "rss")

    expect(Feed.find_by(url: "Status.Example.com/history.rss/")).to eq(feed)
  end

  it "rejects invalid URLs and unknown providers" do
    expect(build(:feed, url: "ftp://example.com")).not_to be_valid
    expect(build(:feed, provider: "carrier_pigeon")).not_to be_valid
  end

  it "falls back to the URL host when it has no name" do
    expect(build(:feed, name: nil, url: "https://www.githubstatus.com/api/v2/incidents.json").display_name).to eq("www.githubstatus.com")
  end
end

RSpec.describe Feed, "#apply_fetch!" do
  let(:feed) { create(:feed, name: nil, site_url: nil) }

  def entry(**attrs)
    FeedProviders::Entry.new(external_id: "inc-1", title: "Outage", impact: "major", status: "investigating",
                             url: "https://stspg.io/1", started_at: Time.utc(2026, 3, 1), resolved_at: nil, **attrs)
  end

  def fetch(entries, **attrs)
    FeedProviders::Fetch.new(entries: entries, name: "GitHub", site_url: "https://www.githubstatus.com", etag: '"e1"', last_modified: nil, **attrs)
  end

  it "stores new incidents and the page details" do
    feed.apply_fetch!(fetch([ entry ]))

    expect(feed.incidents.sole).to have_attributes(external_id: "inc-1", impact: "major", resolved_at: nil)
    expect(feed.reload).to have_attributes(name: "GitHub", site_url: "https://www.githubstatus.com", etag: '"e1"')
  end

  it "updates an existing incident instead of duplicating it" do
    feed.apply_fetch!(fetch([ entry ]))
    feed.apply_fetch!(fetch([ entry(status: "resolved", resolved_at: Time.utc(2026, 3, 1, 2)) ]))

    expect(feed.incidents.sole).to have_attributes(status: "resolved", resolved_at: Time.utc(2026, 3, 1, 2))
  end

  it "keeps incidents that drop out of the source's recent list" do
    feed.apply_fetch!(fetch([ entry ]))
    feed.apply_fetch!(fetch([ entry(external_id: "inc-2") ]))

    expect(feed.incidents.pluck(:external_id)).to contain_exactly("inc-1", "inc-2")
  end

  it "does not overwrite a name that is already set" do
    feed.update!(name: "My Git Host")

    feed.apply_fetch!(fetch([]))

    expect(feed.reload.name).to eq("My Git Host")
  end
end

RSpec.describe Feed, ".resolve!" do
  let(:detector) { instance_double(FeedProviders::Detector) }
  let(:result) { FeedProviders::Detector::Result.new(provider: "statuspage", url: "https://www.githubstatus.com/api/v2/incidents.json", name: "GitHub") }

  it "creates a feed from the detected provider and canonical URL" do
    allow(detector).to receive(:detect).with("githubstatus.com", provider: nil).and_return(result)

    feed = Feed.resolve!("githubstatus.com", detector: detector)

    expect(feed).to have_attributes(provider: "statuspage", url: result.url, name: "GitHub")
  end

  it "reuses one feed for different inputs that resolve to the same canonical URL" do
    allow(detector).to receive(:detect).and_return(result)

    first = Feed.resolve!("githubstatus.com", detector: detector)
    second = Feed.resolve!("https://www.githubstatus.com/", detector: detector)

    expect(second).to eq(first)
    expect(Feed.count).to eq(1)
  end

  it "skips detection when the URL already matches a feed" do
    existing = create(:feed, url: "https://www.githubstatus.com/api/v2/incidents.json")
    allow(detector).to receive(:detect)

    expect(Feed.resolve!("www.githubstatus.com/api/v2/incidents.json/", detector: detector)).to eq(existing)
    expect(detector).not_to have_received(:detect)
  end

  it "passes a manual provider override to detection" do
    allow(detector).to receive(:detect).with("githubstatus.com", provider: "rss")
      .and_return(FeedProviders::Detector::Result.new(provider: "rss", url: "https://www.githubstatus.com/history.atom", name: "GitHub"))

    expect(Feed.resolve!("githubstatus.com", provider: "rss", detector: detector)).to have_attributes(provider: "rss")
  end
end

RSpec.describe Feed, "polling" do
  let(:feed) { create(:feed, url: "https://www.githubstatus.com/api/v2/incidents.json", name: nil) }
  let(:now) { Time.utc(2026, 3, 10, 12) }

  def stub_feed(**response)
    stub_request(:get, feed.url).to_return(**response)
  end

  describe "#poll!" do
    it "stores incidents and schedules the next poll on success" do
      stub_feed(status: 200, body: file_fixture("statuspage/incidents.json").read, headers: { "ETag" => '"v1"' })

      expect(feed.poll!(now: now)).to be(true)

      expect(feed.incidents.count).to eq(4)
      expect(feed.reload).to have_attributes(
        name: "GitHub", etag: '"v1"', last_polled_at: now, last_success_at: now,
        consecutive_failures: 0, last_error: nil, next_poll_at: now + 5.minutes
      )
    end

    it "keeps existing incidents when the source is unchanged" do
      create(:incident, feed: feed)
      feed.update!(etag: '"v1"')
      stub_feed(status: 304)

      feed.poll!(now: now)

      expect(feed.incidents.count).to eq(1)
      expect(feed.reload).to have_attributes(last_success_at: now, next_poll_at: now + 5.minutes)
    end

    it "records failures and backs off exponentially, capped at an hour" do
      stub_feed(status: 503)

      delays = 6.times.map do
        feed.poll!(now: now)
        feed.reload.next_poll_at - now
      end

      expect(delays).to eq([ 5, 10, 20, 40, 60, 60 ].map(&:minutes))
      expect(feed).to have_attributes(consecutive_failures: 6, last_error: "HTTP 503", last_polled_at: now)
      expect(feed).to be_failing
    end

    it "recovers after a failure" do
      feed.update!(consecutive_failures: 3, last_error: "HTTP 503")
      stub_feed(status: 200, body: file_fixture("statuspage/incidents.json").read)

      feed.poll!(now: now)

      expect(feed.reload).to have_attributes(consecutive_failures: 0, last_error: nil, next_poll_at: now + 5.minutes)
    end
  end

  describe ".due" do
    it "includes subscribed feeds that have never been polled or whose poll time has passed" do
      never = create(:subscription).feed
      overdue = create(:subscription, feed: create(:feed, next_poll_at: now - 1.minute)).feed
      create(:subscription, feed: create(:feed, next_poll_at: now + 1.minute))
      create(:feed, next_poll_at: nil) # dormant: no subscribers

      expect(Feed.due(now)).to contain_exactly(never, overdue)
    end
  end
end

RSpec.describe Feed, "live dashboard refreshes" do
  let(:feed) { create(:feed, url: "https://www.githubstatus.com/api/v2/incidents.json", name: "GitHub") }
  let!(:subscribers) { create_list(:subscription, 2, feed: feed).map(&:user) }
  let(:body) { file_fixture("statuspage/incidents.json").read }

  let(:refreshes) { [] }

  before do
    allow(Turbo::StreamsChannel).to receive(:broadcast_refresh_later_to) { |*args| refreshes << args }
  end

  it "refreshes every subscriber's dashboard when incidents change" do
    stub_request(:get, feed.url).to_return(status: 200, body: body)

    feed.poll!

    expect(refreshes).to contain_exactly(*subscribers.map { |user| [ user, :dashboard ] })
  end

  it "does not refresh when nothing changed" do
    stub_request(:get, feed.url).to_return(status: 200, body: body)
    feed.poll!
    refreshes.clear

    feed.poll!

    expect(refreshes).to be_empty
  end

  it "refreshes when the status page starts failing, but not on every repeated failure" do
    feed.update!(last_success_at: 1.hour.ago)
    stub_request(:get, feed.url).to_return(status: 503)

    feed.poll!
    expect(refreshes.size).to eq(2)

    feed.poll!
    expect(refreshes.size).to eq(2)
  end
end
