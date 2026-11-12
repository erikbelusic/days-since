# Atlassian Statuspage public API: <page>/api/v2/incidents.json
module FeedProviders
  class Statuspage
    MAINTENANCE_STATUSES = %w[ scheduled in_progress verifying completed ].freeze

    def fetch(feed)
      response = HttpClient.get(feed.url, etag: feed.etag, last_modified: feed.last_modified, accept: "application/json")
      return Fetch.new(entries: nil, name: nil, site_url: nil, etag: feed.etag, last_modified: feed.last_modified) if response.not_modified?
      raise FetchError, "HTTP #{response.status}" unless response.success?

      parse(response.body).with(etag: response.etag, last_modified: response.last_modified)
    rescue HttpClient::Error => e
      raise FetchError, e.message
    end

    def parse(body)
      data = JSON.parse(body)
      incidents = data.fetch("incidents")
      page = data["page"] || {}

      Fetch.new(
        entries: incidents.reject { |incident| maintenance?(incident) }.map { |incident| entry_for(incident) },
        name: page["name"],
        site_url: page["url"],
        etag: nil,
        last_modified: nil
      )
    rescue JSON::ParserError, KeyError, TypeError => e
      raise FetchError, "Unexpected Statuspage response (#{e.class.name.demodulize})"
    end

    private
      def maintenance?(incident)
        incident["impact"] == "maintenance" || incident["scheduled_for"].present? || MAINTENANCE_STATUSES.include?(incident["status"])
      end

      def entry_for(incident)
        Entry.new(
          external_id: incident.fetch("id"),
          title: incident["name"].presence || "Untitled incident",
          impact: Severity::LEVELS.include?(incident["impact"]) ? incident["impact"] : Severity::UNKNOWN,
          status: incident["status"],
          url: incident["shortlink"],
          started_at: time(incident["started_at"]) || time(incident["created_at"]),
          resolved_at: time(incident["resolved_at"])
        )
      end

      def time(value)
        Time.iso8601(value) if value.present?
      rescue ArgumentError
        nil
      end
  end
end
