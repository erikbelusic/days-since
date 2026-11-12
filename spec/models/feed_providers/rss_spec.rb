require "rails_helper"

RSpec.describe FeedProviders::Rss do
  let(:feed) { create(:feed, :rss, url: "https://slack-status.com/feed/rss") }

  def fetch_fixture(name, headers: {})
    stub_request(:get, feed.url).to_return(status: 200, body: file_fixture("rss/#{name}").read, headers: headers)
    described_class.new.fetch(feed)
  end

  context "with an RSS 2.0 feed" do
    it "reads the channel name and site" do
      expect(fetch_fixture("rss2.xml")).to have_attributes(name: "Slack System Status", site_url: "https://slack-status.com")
    end

    it "treats each item as an incident that starts and resolves at its publish time" do
      entry = fetch_fixture("rss2.xml").entries.find { |e| e.external_id == "https://slack-status.com/2026-03/abc123" }

      published = Time.utc(2026, 3, 9, 14, 53, 33)
      expect(entry).to have_attributes(
        title: "Incident: Trouble uploading files", impact: "unknown", url: "https://slack-status.com/2026-03/abc123",
        started_at: published, resolved_at: published
      )
    end

    it "falls back to the link when an item has no guid" do
      ids = fetch_fixture("rss2.xml").entries.map(&:external_id)

      expect(ids).to include("https://slack-status.com/2026-02/def456")
    end

    it "skips maintenance posts and items without a date" do
      titles = fetch_fixture("rss2.xml").entries.map(&:title)

      expect(titles).to contain_exactly("Incident: Trouble uploading files", "Incident: Messages delayed")
    end
  end

  context "with an Atom feed" do
    it "uses published time, falling back to updated" do
      fetch = fetch_fixture("atom.xml")
      by_id = fetch.entries.index_by(&:external_id)

      expect(fetch).to have_attributes(name: "Heroku Status", site_url: "https://status.heroku.com/")
      expect(by_id["tag:status.heroku.com,2026:Incident/2901"].started_at).to eq(Time.utc(2026, 3, 7, 9))
      expect(by_id["tag:status.heroku.com,2026:Incident/2899"].resolved_at).to eq(Time.utc(2026, 3, 1, 12, 30))
    end
  end

  it "records caching headers and honors not-modified responses" do
    expect(fetch_fixture("atom.xml", headers: { "ETag" => '"r1"' }).etag).to eq('"r1"')

    feed.update!(etag: '"r1"')
    stub_request(:get, feed.url).with(headers: { "If-None-Match" => '"r1"' }).to_return(status: 304)
    expect(described_class.new.fetch(feed)).to be_not_modified
  end

  it "raises a fetch error for non-feed content and HTTP failures" do
    stub_request(:get, feed.url).to_return(status: 200, body: "<html><body>Status page</body></html>")
    expect { described_class.new.fetch(feed) }.to raise_error(FeedProviders::FetchError, "Not an RSS or Atom feed")

    stub_request(:get, feed.url).to_return(status: 404)
    expect { described_class.new.fetch(feed) }.to raise_error(FeedProviders::FetchError, "HTTP 404")
  end
end
