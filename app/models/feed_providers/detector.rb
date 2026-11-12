# Works out which provider serves a user-entered status URL and the canonical
# URL to poll (which is also the dedup key for Feeds):
#
#   1. Load the page (following redirects, e.g. githubstatus.com -> www.).
#   2. If <root>/api/v2/summary.json answers, it's Statuspage, polled at
#      <root>/api/v2/incidents.json.
#   3. If the page itself is an RSS/Atom feed, poll it directly.
#   4. If the HTML advertises a feed via <link rel="alternate">, poll that.
#   5. Otherwise try a few common feed paths (/feed, /history.rss, ...).
#
# Passing provider: forces one provider (manual override).
module FeedProviders
  class Detector
    Result = Data.define(:provider, :url, :name)

    class Failed < StandardError; end

    API_PATH = %r{/api/v2(/.*)?\z}
    FEED_TYPES = %w[ application/rss+xml application/atom+xml ].freeze
    COMMON_FEED_PATHS = %w[ /feed /feed/rss /feed.rss /feed.atom /rss /atom.xml /history.rss /history.atom ].freeze

    def detect(input, provider: nil)
      url = FeedUrl.normalize(input)
      page = fetch_page(url)

      result =
        case provider.presence
        when nil then statuspage(page.url) || rss(page)
        when "statuspage" then statuspage(page.url)
        when "rss" then rss(page)
        else raise Failed, "Unknown provider #{provider.inspect}"
        end

      result || raise(Failed, failure_message(provider))
    rescue FeedUrl::Invalid => e
      raise Failed, e.message
    end

    private
      def fetch_page(url)
        response = HttpClient.get(url)
        raise Failed, "#{url} responded with HTTP #{response.status}" unless response.success? || statuspage_api?(url)
        response
      rescue HttpClient::Error
        raise Failed, "Couldn't reach #{url}"
      end

      def statuspage(page_url)
        root = statuspage_root(page_url)
        response = HttpClient.get("#{root}/api/v2/summary.json", accept: "application/json")
        return unless response.success?

        data = JSON.parse(response.body)
        return unless data.dig("page", "id")

        Result.new(provider: "statuspage", url: FeedUrl.normalize("#{root}/api/v2/incidents.json"), name: data.dig("page", "name"))
      rescue HttpClient::Error, JSON::ParserError, TypeError
        nil
      end

      def rss(page)
        feed_from(page.body, page.url) || discovered_feed(page) || common_path_feed(page.url)
      end

      def discovered_feed(page)
        return unless page.content_type.include?("html") || page.body.lstrip.start_with?("<!", "<html")

        Nokogiri::HTML(page.body).css("link[rel~='alternate']").each do |link|
          next unless FEED_TYPES.include?(link["type"].to_s.downcase.strip)

          result = feed_at(URI.join(page.url, link["href"].to_s.strip).to_s)
          return result if result
        rescue URI::Error
          next
        end
        nil
      end

      # Last resort for pages that publish a feed without advertising it.
      def common_path_feed(page_url)
        root = URI.join(page_url, "/").to_s.chomp("/")
        COMMON_FEED_PATHS.each do |path|
          result = feed_at("#{root}#{path}")
          return result if result
        end
        nil
      end

      def feed_at(url)
        response = HttpClient.get(url, accept: Rss::ACCEPT)
        feed_from(response.body, response.url) if response.success?
      rescue HttpClient::Error
        nil
      end

      def feed_from(body, url)
        parsed = Rss.new.parse(body)
        Result.new(provider: "rss", url: FeedUrl.normalize(url), name: parsed.name)
      rescue FetchError
        nil
      end

      def statuspage_root(url)
        uri = URI.parse(FeedUrl.normalize(url))
        uri.path = uri.path.sub(API_PATH, "")
        uri.to_s.chomp("/")
      end

      def statuspage_api?(url)
        URI.parse(url).path.match?(API_PATH)
      end

      def failure_message(provider)
        case provider.presence
        when "statuspage" then "That URL doesn't look like an Atlassian Statuspage page"
        when "rss" then "Couldn't find an RSS or Atom feed at that URL"
        else "Couldn't find a Statuspage API or an RSS/Atom feed at that URL"
        end
      end
  end
end
