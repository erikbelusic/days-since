# Provider adapters turn a Feed's remote source into normalized incident
# entries. Each provider exposes #fetch(feed) returning a FeedProviders::Fetch.
module FeedProviders
  class FetchError < StandardError; end

  Entry = Data.define(:external_id, :title, :impact, :status, :url, :started_at, :resolved_at)

  # entries is nil when the source reported "not modified".
  Fetch = Data.define(:entries, :name, :site_url, :etag, :last_modified) do
    def not_modified? = entries.nil?
  end

  def self.for(feed)
    case feed.provider
    when "statuspage" then Statuspage.new
    when "rss" then Rss.new
    else raise ArgumentError, "No provider for #{feed.provider.inspect}"
    end
  end
end
