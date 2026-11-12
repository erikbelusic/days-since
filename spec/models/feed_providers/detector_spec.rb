require "rails_helper"

RSpec.describe FeedProviders::Detector do
  subject(:detector) { described_class.new }

  let(:summary) { file_fixture("statuspage/summary.json").read }
  let(:atom) { file_fixture("rss/atom.xml").read }

  before do
    # Anything not explicitly stubbed is "not found".
    stub_request(:any, /.*/).to_return(status: 404)
  end

  def stub_github
    stub_request(:get, "https://githubstatus.com/").to_return(status: 301, headers: { "Location" => "https://www.githubstatus.com/" })
    stub_request(:get, "https://githubstatus.com").to_return(status: 301, headers: { "Location" => "https://www.githubstatus.com/" })
    stub_request(:get, "https://www.githubstatus.com/").to_return(status: 200, body: "<html><head><link rel=\"alternate\" type=\"application/atom+xml\" href=\"/history.atom\"></head></html>", headers: { "Content-Type" => "text/html" })
    stub_request(:get, "https://www.githubstatus.com/api/v2/summary.json").to_return(status: 200, body: summary)
    stub_request(:get, "https://www.githubstatus.com/history.atom").to_return(status: 200, body: atom)
  end

  def stub_stripe
    stub_request(:get, "https://status.stripe.com").to_return(status: 200, body: file_fixture("html/stripe_status.html").read, headers: { "Content-Type" => "text/html; charset=utf-8" })
    stub_request(:get, "https://status.stripe.com/current/atom.xml").to_return(status: 200, body: atom)
  end

  it "detects Statuspage after following redirects and prefers it over advertised feeds" do
    stub_github

    result = detector.detect("githubstatus.com")

    expect(result).to have_attributes(provider: "statuspage", url: "https://www.githubstatus.com/api/v2/incidents.json", name: "GitHub")
  end

  it "accepts a Statuspage API URL directly" do
    stub_github
    stub_request(:get, "https://www.githubstatus.com/api/v2/incidents.json").to_return(status: 200, body: file_fixture("statuspage/incidents.json").read)

    result = detector.detect("https://www.githubstatus.com/api/v2/incidents.json")

    expect(result).to have_attributes(provider: "statuspage", url: "https://www.githubstatus.com/api/v2/incidents.json")
  end

  it "discovers an RSS/Atom feed advertised by the page" do
    stub_stripe

    result = detector.detect("https://status.stripe.com")

    expect(result).to have_attributes(provider: "rss", url: "https://status.stripe.com/current/atom.xml", name: "Heroku Status")
  end

  it "accepts a feed URL directly" do
    stub_request(:get, "https://status.heroku.com/feed").to_return(status: 200, body: atom, headers: { "Content-Type" => "application/atom+xml" })

    expect(detector.detect("status.heroku.com/feed")).to have_attributes(provider: "rss", url: "https://status.heroku.com/feed")
  end

  it "finds a feed at a common path when the page doesn't advertise one" do
    stub_request(:get, "https://slack-status.com").to_return(status: 200, body: file_fixture("html/plain_page.html").read, headers: { "Content-Type" => "text/html" })
    stub_request(:get, "https://slack-status.com/feed/rss").to_return(status: 200, body: file_fixture("rss/rss2.xml").read)

    expect(detector.detect("slack-status.com")).to have_attributes(provider: "rss", url: "https://slack-status.com/feed/rss")
  end

  it "uses the feed when the user overrides detection to RSS" do
    stub_github

    result = detector.detect("githubstatus.com", provider: "rss")

    expect(result).to have_attributes(provider: "rss", url: "https://www.githubstatus.com/history.atom")
  end

  it "refuses a Statuspage override for a page that isn't Statuspage" do
    stub_stripe

    expect { detector.detect("status.stripe.com", provider: "statuspage") }
      .to raise_error(FeedProviders::Detector::Failed, /doesn't look like an Atlassian Statuspage/)
  end

  it "explains when nothing usable is found" do
    stub_request(:get, "https://example.com").to_return(status: 200, body: file_fixture("html/plain_page.html").read, headers: { "Content-Type" => "text/html" })

    expect { detector.detect("example.com") }
      .to raise_error(FeedProviders::Detector::Failed, "Couldn't find a Statuspage API or an RSS/Atom feed at that URL")
  end

  it "explains unreachable and invalid URLs" do
    stub_request(:get, "https://down.example.com").to_timeout

    expect { detector.detect("down.example.com") }.to raise_error(FeedProviders::Detector::Failed, "Couldn't reach https://down.example.com")
    expect { detector.detect("ftp://example.com") }.to raise_error(FeedProviders::Detector::Failed, /http or https/)
    expect { detector.detect("https://example.com/missing") }.to raise_error(FeedProviders::Detector::Failed, /HTTP 404/)
  end
end
