# Stubs a Statuspage-hosted status site at https://<host> for detection and
# polling, using the hand-written fixtures in spec/fixtures/files/statuspage.
module StatusPageStubs
  def stub_statuspage_site(host, name: "GitHub")
    summary = JSON.parse(file_fixture("statuspage/summary.json").read)
    summary["page"]["name"] = name
    incidents = JSON.parse(file_fixture("statuspage/incidents.json").read)
    incidents["page"]["name"] = name

    stub_request(:get, %r{\Ahttps://#{Regexp.escape(host)}/?\z}).to_return(status: 200, body: "<html></html>", headers: { "Content-Type" => "text/html" })
    stub_request(:get, "https://#{host}/api/v2/summary.json").to_return(status: 200, body: summary.to_json)
    stub_request(:get, "https://#{host}/api/v2/incidents.json").to_return(status: 200, body: incidents.to_json)
  end
end

RSpec.configure do |config|
  config.include StatusPageStubs
end
