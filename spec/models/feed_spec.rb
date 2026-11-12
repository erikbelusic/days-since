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
