class PollFeedJob < ApplicationJob
  queue_as :default

  # Never poll the same feed twice at once; a duplicate is simply dropped.
  limits_concurrency to: 1, key: ->(feed) { feed }, on_conflict: :discard

  discard_on ActiveJob::DeserializationError

  def perform(feed)
    feed.poll! if feed.subscribed?
  end
end
