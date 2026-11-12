# A status source, shared by every user who subscribes to the same canonical
# URL so each source is polled once no matter how many subscribers it has.
class Feed < ApplicationRecord
  POLL_INTERVAL = 5.minutes
  MAX_BACKOFF = 1.hour

  enum :provider, { statuspage: "statuspage", rss: "rss" }, validate: true
  has_many :incidents, dependent: :delete_all
  has_many :subscriptions, dependent: :restrict_with_error

  # Feeds nobody subscribes to keep their history but are not polled.
  scope :subscribed, -> { where(id: Subscription.select(:feed_id)) }
  scope :due, ->(now = Time.current) { subscribed.where(next_poll_at: nil).or(subscribed.where(next_poll_at: ..now)) }

  normalizes :url, with: ->(url) { FeedUrl.normalize_or_nil(url) || url.to_s.strip }

  validates :url, presence: true, uniqueness: true
  validate :url_must_be_http

  # Finds or creates the shared Feed for a user-entered URL. A URL that already
  # matches a feed skips detection; otherwise the detector picks the provider
  # and canonical URL, so equivalent inputs land on the same Feed.
  def self.resolve!(input, provider: nil, detector: FeedProviders::Detector.new)
    if provider.blank? && (existing = find_by(url: FeedUrl.normalize_or_nil(input)))
      return existing
    end

    result = detector.detect(input, provider: provider)
    find_or_create_by!(url: result.url) do |feed|
      feed.provider = result.provider
      feed.name = result.name
    end
  rescue ActiveRecord::RecordNotUnique
    find_by!(url: result.url)
  end

  def subscribed?
    subscriptions.exists?
  end

  # Applies a provider fetch: records caching headers, fills in the page name
  # and site URL, and upserts every incident entry by its external id.
  def apply_fetch!(fetch)
    transaction do
      self.etag = fetch.etag
      self.last_modified = fetch.last_modified
      self.name = fetch.name if name.blank? && fetch.name.present?
      self.site_url = fetch.site_url if site_url.blank? && fetch.site_url.present?
      save!

      Array(fetch.entries).each do |entry|
        incident = incidents.find_or_initialize_by(external_id: entry.external_id)
        incident.update!(entry.to_h.except(:external_id))
      end
    end
  end

  # Fetches the feed from its provider and records the outcome. Failures never
  # raise: they're stored on the feed and push the next poll out with
  # exponential backoff (5m, 10m, 20m, 40m, then capped at 1h).
  def poll!(now: Time.current)
    fetch = FeedProviders.for(self).fetch(self)
    apply_fetch!(fetch) unless fetch.not_modified?
    update!(last_polled_at: now, last_success_at: now, consecutive_failures: 0, last_error: nil, next_poll_at: now + POLL_INTERVAL)
    true
  rescue FeedProviders::FetchError => e
    failures = consecutive_failures + 1
    update!(last_polled_at: now, consecutive_failures: failures, last_error: e.message.truncate(500), next_poll_at: now + backoff_after(failures))
    false
  end

  def failing?
    consecutive_failures.positive?
  end

  def display_name
    name.presence || URI.parse(url).host
  end

  private
    def backoff_after(failures)
      [ POLL_INTERVAL * (2**(failures - 1)), MAX_BACKOFF ].min
    end

    def url_must_be_http
      FeedUrl.normalize(url) if url.present?
    rescue FeedUrl::Invalid => e
      errors.add(:url, e.message.delete_prefix("URL ").sub(/\A./, &:downcase))
    end
end
