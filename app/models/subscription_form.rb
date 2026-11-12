# Backs the "Add status page" form: detects the provider (synchronously, so
# errors show inline), finds or creates the shared Feed, subscribes the user,
# and kicks off a first poll for brand-new feeds.
class SubscriptionForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  PROVIDER_OPTIONS = [ [ "Detect automatically", "" ], [ "Atlassian Statuspage", "statuspage" ], [ "RSS / Atom feed", "rss" ] ].freeze

  attribute :url, :string
  attribute :provider, :string
  attribute :display_name, :string

  attr_accessor :user
  attr_reader :subscription

  validates :url, presence: true
  validates :provider, inclusion: { in: Feed.providers.keys }, allow_blank: true

  def save
    return false unless valid?

    feed = Feed.resolve!(url, provider: provider.presence)
    @subscription = user.subscriptions.build(feed: feed, display_name: display_name)

    if @subscription.save
      PollFeedJob.perform_later(feed) if feed.last_polled_at.nil?
      FetchFeedLogoJob.perform_later(feed) if feed.logo_checked_at.nil?
      true
    else
      @subscription.errors.each { |error| errors.add(:base, error.full_message) }
      false
    end
  rescue FeedProviders::Detector::Failed => e
    errors.add(:base, e.message)
    false
  end
end
