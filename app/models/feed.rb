# A status source, shared by every user who subscribes to the same canonical
# URL so each source is polled once no matter how many subscribers it has.
class Feed < ApplicationRecord
  enum :provider, { statuspage: "statuspage", rss: "rss" }, validate: true

  normalizes :url, with: ->(url) { FeedUrl.normalize_or_nil(url) || url.to_s.strip }

  validates :url, presence: true, uniqueness: true
  validate :url_must_be_http

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
