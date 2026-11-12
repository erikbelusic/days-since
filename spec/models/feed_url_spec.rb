require "rails_helper"

RSpec.describe FeedUrl do
  describe ".normalize" do
    {
      "githubstatus.com" => "https://githubstatus.com",
      "https://www.GitHubStatus.com/" => "https://www.githubstatus.com",
      "  https://status.example.com/history.rss  " => "https://status.example.com/history.rss",
      "HTTP://Status.Example.com:80/feed/" => "http://status.example.com/feed",
      "https://status.example.com:443/api/v2/incidents.json?utm_source=x#top" => "https://status.example.com/api/v2/incidents.json",
      "https://status.example.com:8443/feed" => "https://status.example.com:8443/feed",
      "https://user:pass@status.example.com" => "https://status.example.com"
    }.each do |input, expected|
      it "normalizes #{input.strip.inspect} to #{expected.inspect}" do
        expect(described_class.normalize(input)).to eq(expected)
      end
    end

    it "treats equivalent inputs as the same URL" do
      variants = [ "status.example.com", "https://status.example.com/", "HTTPS://STATUS.EXAMPLE.COM//" ]

      expect(variants.map { |v| described_class.normalize(v) }.uniq.size).to eq(1)
    end

    it "rejects blank, non-http, and malformed input" do
      [ "", "   ", "ftp://example.com/feed", "https://", "http://exa mple.com" ].each do |input|
        expect { described_class.normalize(input) }.to raise_error(FeedUrl::Invalid), "expected #{input.inspect} to be rejected"
      end
    end
  end
end
