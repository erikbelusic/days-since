require "rails_helper"

RSpec.describe HttpClient do
  let(:url) { "https://status.example.com/api/v2/incidents.json" }

  it "returns the body, status, and caching headers" do
    stub_request(:get, url).to_return(status: 200, body: "{}", headers: { "ETag" => '"abc"', "Last-Modified" => "Tue, 10 Mar 2026 12:00:00 GMT" })

    response = described_class.get(url)

    expect(response).to be_success
    expect(response).to have_attributes(body: "{}", etag: '"abc"', last_modified: "Tue, 10 Mar 2026 12:00:00 GMT")
  end

  it "identifies itself with a descriptive user agent" do
    stub_request(:get, url).to_return(status: 200)

    described_class.get(url)

    expect(a_request(:get, url).with(headers: { "User-Agent" => HttpClient::USER_AGENT })).to have_been_made
  end

  it "makes conditional requests and reports unchanged content" do
    stub_request(:get, url).with(headers: { "If-None-Match" => '"abc"', "If-Modified-Since" => "Tue, 10 Mar 2026 12:00:00 GMT" }).to_return(status: 304)

    response = described_class.get(url, etag: '"abc"', last_modified: "Tue, 10 Mar 2026 12:00:00 GMT")

    expect(response).to be_not_modified
  end

  it "follows redirects and reports the final URL" do
    stub_request(:get, "https://githubstatus.com/").to_return(status: 301, headers: { "Location" => "https://www.githubstatus.com/" })
    stub_request(:get, "https://www.githubstatus.com/").to_return(status: 200, body: "ok")

    response = described_class.get("https://githubstatus.com/")

    expect(response).to have_attributes(status: 200, body: "ok", url: "https://www.githubstatus.com/")
  end

  it "returns error statuses rather than raising" do
    stub_request(:get, url).to_return(status: 503)

    expect(described_class.get(url)).to have_attributes(status: 503, success?: false)
  end

  it "raises a single error type when the server can't be reached" do
    stub_request(:get, url).to_timeout
    expect { described_class.get(url) }.to raise_error(HttpClient::Error)

    stub_request(:get, url).to_raise(Faraday::ConnectionFailed.new("connection refused"))
    expect { described_class.get(url) }.to raise_error(HttpClient::Error, /refused/)
  end
end
