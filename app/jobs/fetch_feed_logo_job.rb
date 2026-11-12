class FetchFeedLogoJob < ApplicationJob
  queue_as :default

  limits_concurrency to: 1, key: ->(feed) { feed }, on_conflict: :discard
  discard_on ActiveJob::DeserializationError

  def perform(feed)
    FeedLogo.refresh!(feed) if feed.subscribed?
  end
end
