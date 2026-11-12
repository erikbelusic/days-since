require "feedjira"

# Generic RSS 2.0 / Atom status feeds. These have no structured severity or
# resolved state, so each entry is an incident of unknown severity that starts
# and resolves at its publish time (see README "Providers").
module FeedProviders
  class Rss
    ACCEPT = "application/rss+xml, application/atom+xml, application/xml;q=0.9, text/xml;q=0.8".freeze
    MAINTENANCE_TITLE = /\A\s*(\[?scheduled\]?\s*)?maintenance\b|\bscheduled maintenance\b/i

    def fetch(feed)
      response = HttpClient.get(feed.url, etag: feed.etag, last_modified: feed.last_modified, accept: ACCEPT)
      return Fetch.new(entries: nil, name: nil, site_url: nil, etag: feed.etag, last_modified: feed.last_modified) if response.not_modified?
      raise FetchError, "HTTP #{response.status}" unless response.success?

      parse(response.body).with(etag: response.etag, last_modified: response.last_modified)
    rescue HttpClient::Error => e
      raise FetchError, e.message
    end

    def parse(body)
      parsed = Feedjira.parse(body)

      Fetch.new(
        entries: parsed.entries.filter_map { |entry| entry_for(entry) },
        name: parsed.title&.strip.presence,
        site_url: parsed.url&.strip.presence,
        etag: nil,
        last_modified: nil
      )
    rescue Feedjira::NoParserAvailable
      raise FetchError, "Not an RSS or Atom feed"
    end

    private
      def entry_for(entry)
        title = entry.title.to_s.squish
        time = entry.published || entry.try(:updated)
        return if time.nil? || title.match?(MAINTENANCE_TITLE)

        link = entry.url.to_s.strip.presence
        Entry.new(
          external_id: entry.entry_id.to_s.strip.presence || link || Digest::SHA256.hexdigest("#{title}|#{time.iso8601}"),
          title: title.presence || "Untitled incident",
          impact: Severity::UNKNOWN,
          status: nil,
          url: link,
          started_at: time.utc,
          resolved_at: time.utc
        )
      end
  end
end
