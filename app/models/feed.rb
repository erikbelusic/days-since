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
  # Returns true when anything a subscriber would see changed.
  def apply_fetch!(fetch)
    transaction do
      self.etag = fetch.etag
      self.last_modified = fetch.last_modified
      self.name = fetch.name if name.blank? && fetch.name.present?
      self.site_url = fetch.site_url if site_url.blank? && fetch.site_url.present?
      visible_change = name_changed?
      save!

      Array(fetch.entries).each do |entry|
        incident = incidents.find_or_initialize_by(external_id: entry.external_id)
        incident.assign_attributes(entry.to_h.except(:external_id))
        visible_change = true if incident.changed?
        incident.save!
      end

      visible_change
    end
  end

  # Fetches the feed from its provider and records the outcome. Failures never
  # raise: they're stored on the feed and push the next poll out with
  # exponential backoff (5m, 10m, 20m, 40m, then capped at 1h).
  def poll!(now: Time.current)
    status_before = card_status
    fetch = FeedProviders.for(self).fetch(self)
    incidents_changed = fetch.not_modified? ? false : apply_fetch!(fetch)
    update!(last_polled_at: now, last_success_at: now, consecutive_failures: 0, last_error: nil, next_poll_at: now + POLL_INTERVAL)
    refresh_subscriber_dashboards if incidents_changed || card_status != status_before
    true
  rescue FeedProviders::FetchError => e
    failures = consecutive_failures + 1
    update!(last_polled_at: now, consecutive_failures: failures, last_error: e.message.truncate(500), next_poll_at: now + backoff_after(failures))
    refresh_subscriber_dashboards if card_status != status_before
    false
  end

  # Asks every subscriber's open dashboard to refresh (Turbo morph), so each
  # user re-renders cards in their own theme, time zone, and thresholds.
  def refresh_subscriber_dashboards
    User.where(id: subscriptions.select(:user_id)).find_each do |user|
      Turbo::StreamsChannel.broadcast_refresh_later_to(user, :dashboard)
    end
  end

  def failing?
    consecutive_failures.positive?
  end

  def display_name
    name.presence || URI.parse(url).host
  end

  private
    # The feed-level state shown on cards (waiting / failing / ok).
    def card_status
      [ last_success_at.nil?, failing?, last_error ]
    end

    def backoff_after(failures)
      [ POLL_INTERVAL * (2**(failures - 1)), MAX_BACKOFF ].min
    end

    def url_must_be_http
      FeedUrl.normalize(url) if url.present?
    rescue FeedUrl::Invalid => e
      errors.add(:url, e.message.delete_prefix("URL ").sub(/\A./, &:downcase))
    end
end
