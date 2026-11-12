require "rails_helper"

RSpec.describe FeedProviders::Statuspage do
  let(:feed) { create(:feed, url: "https://www.githubstatus.com/api/v2/incidents.json", name: nil) }
  let(:body) { file_fixture("statuspage/incidents.json").read }

  def stub_incidents(status: 200, body: self.body, headers: { "ETag" => '"v1"' })
    stub_request(:get, feed.url).to_return(status: status, body: body, headers: headers)
  end

  it "turns incidents into entries with impact, status, link, and times" do
    stub_incidents

    fetch = described_class.new.fetch(feed)
    major = fetch.entries.find { |e| e.external_id == "major1" }

    expect(fetch).to have_attributes(name: "GitHub", site_url: "https://www.githubstatus.com", etag: '"v1"')
    expect(major).to have_attributes(
      title: "Incident with Git operations", impact: "major", status: "resolved", url: "https://stspg.io/major1",
      started_at: Time.utc(2026, 3, 5, 14), resolved_at: Time.utc(2026, 3, 5, 15, 30)
    )
  end

  it "keeps unresolved incidents open" do
    stub_incidents

    ongoing = described_class.new.fetch(feed).entries.find { |e| e.external_id == "ongoing1" }

    expect(ongoing).to have_attributes(status: "identified", resolved_at: nil)
  end

  it "skips scheduled maintenance" do
    stub_incidents

    expect(described_class.new.fetch(feed).entries.map(&:external_id)).not_to include("maint1")
  end

  it "falls back to created_at when started_at is missing" do
    stub_incidents

    postmortem = described_class.new.fetch(feed).entries.find { |e| e.external_id == "postmortem1" }

    expect(postmortem.started_at).to eq(Time.utc(2026, 2, 20, 10))
  end

  it "sends conditional headers and reports an unchanged source" do
    feed.update!(etag: '"v1"')
    stub_request(:get, feed.url).with(headers: { "If-None-Match" => '"v1"' }).to_return(status: 304)

    expect(described_class.new.fetch(feed)).to be_not_modified
  end

  it "raises a fetch error for HTTP failures, bad payloads, and unreachable hosts" do
    stub_incidents(status: 500, body: "oops")
    expect { described_class.new.fetch(feed) }.to raise_error(FeedProviders::FetchError, "HTTP 500")

    stub_incidents(body: "<html>not json</html>")
    expect { described_class.new.fetch(feed) }.to raise_error(FeedProviders::FetchError, /Unexpected Statuspage response/)

    stub_request(:get, feed.url).to_timeout
    expect { described_class.new.fetch(feed) }.to raise_error(FeedProviders::FetchError)
  end
end
