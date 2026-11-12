require "rails_helper"

RSpec.describe FeedLogo do
  let(:png) { file_fixture("logos/icon.png").binread }
  let(:feed) { create(:feed, url: "https://status.example.com/api/v2/incidents.json", site_url: "https://status.example.com") }
  let(:now) { Time.utc(2026, 3, 10, 12) }

  before { stub_request(:any, /.*/).to_return(status: 404) }

  def stub_page(head)
    stub_request(:get, "https://status.example.com").to_return(status: 200, body: "<html><head>#{head}</head></html>", headers: { "Content-Type" => "text/html" })
  end

  def stub_image(url, body: png, type: "image/png")
    stub_request(:get, url).to_return(status: 200, body: body, headers: { "Content-Type" => type })
  end

  it "prefers apple-touch-icon, then the largest declared icon, then /favicon.ico" do
    stub_page(<<~HTML)
      <link rel="icon" sizes="16x16" href="/small.png">
      <link rel="shortcut icon" sizes="64x64" href="//cdn.example.net/big.png">
      <link rel="apple-touch-icon" href="/touch.png">
    HTML

    expect(described_class.new(feed).candidate_urls).to eq([
      "https://status.example.com/touch.png",
      "https://cdn.example.net/big.png",
      "https://status.example.com/small.png",
      "https://status.example.com/favicon.ico"
    ])
  end

  it "stores the first candidate that is really an image" do
    stub_page(%(<link rel="icon" href="/fake.png"><link rel="icon" href="/real.png">))
    stub_image("https://status.example.com/fake.png", body: "<html>not an icon</html>", type: "image/png")
    stub_image("https://status.example.com/real.png", type: "text/plain") # wrong header, real PNG bytes

    expect(described_class.refresh!(feed, now: now)).to be(true)

    expect(feed.logo.content_type).to eq("image/png")
    expect(feed.logo.download).to eq(png)
    expect(feed.reload.logo_checked_at).to eq(now)
  end

  it "skips SVG icons" do
    stub_page(%(<link rel="icon" type="image/svg+xml" href="/icon.svg">))
    stub_image("https://status.example.com/icon.svg", body: "<svg xmlns='http://www.w3.org/2000/svg'/>", type: "image/svg+xml")
    stub_image("https://status.example.com/favicon.ico")

    described_class.refresh!(feed)

    expect(a_request(:get, "https://status.example.com/icon.svg")).not_to have_been_made
    expect(feed.logo).to be_attached
  end

  it "ignores oversized files" do
    stub_page("")
    stub_image("https://status.example.com/favicon.ico", body: png + ("\0" * FeedLogo::MAX_BYTES))

    expect(described_class.refresh!(feed)).to be(false)
  end

  it "falls back to /favicon.ico when the page can't be loaded" do
    stub_request(:get, "https://status.example.com").to_timeout
    stub_image("https://status.example.com/favicon.ico", type: "image/vnd.microsoft.icon")

    expect(described_class.refresh!(feed)).to be(true)
  end

  it "keeps the existing logo when nothing is found and records the check" do
    feed.logo.attach(io: StringIO.new(png), filename: "logo.png", content_type: "image/png")
    stub_request(:get, /status\.example\.com/).to_return(status: 503)

    expect(described_class.refresh!(feed, now: now)).to be(true)
    expect(feed.reload.logo_checked_at).to eq(now)
  end

  it "doesn't re-upload an unchanged logo" do
    stub_page("")
    stub_image("https://status.example.com/favicon.ico")
    described_class.refresh!(feed)

    expect { described_class.refresh!(feed) }.not_to change(ActiveStorage::Blob, :count)
  end

  it "uses the feed URL's site root when the site URL is unknown" do
    feed.update!(site_url: nil)
    stub_page("")
    stub_image("https://status.example.com/favicon.ico")

    expect(described_class.refresh!(feed)).to be(true)
  end
end
