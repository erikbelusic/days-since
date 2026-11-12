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
