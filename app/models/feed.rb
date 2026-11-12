# A status source, shared by every user who subscribes to the same canonical
# URL so each source is polled once no matter how many subscribers it has.
class Feed < ApplicationRecord
  enum :provider, { statuspage: "statuspage", rss: "rss" }, validate: true
  has_many :incidents, dependent: :delete_all
  has_many :subscriptions, dependent: :restrict_with_error

  # Feeds nobody subscribes to keep their history but are not polled.
  scope :subscribed, -> { where(id: Subscription.select(:feed_id)) }

  normalizes :url, with: ->(url) { FeedUrl.normalize_or_nil(url) || url.to_s.strip }

  validates :url, presence: true, uniqueness: true
  validate :url_must_be_http

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

  def display_name
    name.presence || URI.parse(url).host
  end

  private
    def url_must_be_http
      FeedUrl.normalize(url) if url.present?
    rescue FeedUrl::Invalid => e
      errors.add(:url, e.message.delete_prefix("URL ").sub(/\A./, &:downcase))
    end
end
