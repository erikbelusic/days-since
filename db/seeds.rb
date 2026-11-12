# Development-only sample data: gives the local SINGLE_USER_MODE user a few
# real status pages to watch. Safe to re-run; does nothing if the local user
# already has subscriptions. Feeds are created directly (no detection needed),
# and the poller fills in incidents.
if Rails.env.development?
  user = SingleUserMode.user

  if user.subscriptions.none?
    [
      { name: "GitHub", provider: "statuspage", url: "https://www.githubstatus.com/api/v2/incidents.json", site_url: "https://www.githubstatus.com" },
      { name: "Cloudflare", provider: "statuspage", url: "https://www.cloudflarestatus.com/api/v2/incidents.json", site_url: "https://www.cloudflarestatus.com" },
      { name: "Slack", provider: "rss", url: "https://slack-status.com/feed/rss", site_url: "https://slack-status.com" }
    ].each do |attrs|
      feed = Feed.find_or_create_by!(url: attrs[:url]) { |f| f.assign_attributes(attrs.except(:url)) }
      user.subscriptions.create!(feed: feed)
      PollFeedJob.perform_later(feed)
      FetchFeedLogoJob.perform_later(feed)
    end

    puts "Seeded #{user.email_address} with #{user.subscriptions.count} status pages."
  end
end
