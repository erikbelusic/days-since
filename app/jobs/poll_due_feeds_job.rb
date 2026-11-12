# Runs every 5 minutes (config/recurring.yml) and fans out one poll per due feed.
class PollDueFeedsJob < ApplicationJob
  queue_as :default

  def perform
    Feed.due.find_each { |feed| PollFeedJob.perform_later(feed) }
  end
end
