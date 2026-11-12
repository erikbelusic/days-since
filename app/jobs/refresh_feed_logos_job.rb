# Runs daily (config/recurring.yml): re-checks logos for subscribed feeds that
# haven't been looked at for FeedLogo::REFRESH_AFTER.
class RefreshFeedLogosJob < ApplicationJob
  queue_as :default

  def perform(now: Time.current)
    stale = Feed.subscribed.where(logo_checked_at: nil).or(Feed.subscribed.where(logo_checked_at: ...(now - FeedLogo::REFRESH_AFTER)))
    stale.find_each { |feed| FetchFeedLogoJob.perform_later(feed) }
  end
end
