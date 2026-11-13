require "rails_helper"

RSpec.describe "Dashboard", :single_user_mode do
  let(:user) { SingleUserMode.user }

  def card_for(subscription)
    Nokogiri::HTML(response.body).at_css("##{ActionView::RecordIdentifier.dom_id(subscription)}")
  end

  it "shows an empty state when the user has no subscriptions" do
    get root_path

    expect(response.body).to include("No status pages yet")
  end

  it "shows a counter card for each of the user's subscriptions, in order" do
    travel_to Time.utc(2026, 3, 10, 12) do
      github = create(:subscription, user: user, feed: create(:feed, name: "GitHub"))
      create(:incident, feed: github.feed, impact: "major", started_at: Time.utc(2026, 3, 3), resolved_at: Time.utc(2026, 3, 3, 2))
      stripe = create(:subscription, user: user, feed: create(:feed, name: "Stripe"), display_name: "Payments")

      get root_path

      expect(card_for(github).text).to include("GitHub").and include("7").and include("Days since last incident")
      expect(card_for(stripe).text).to include("Payments").and include("∞").and include("No incidents on record")
      expect(response.body.index("GitHub")).to be < response.body.index("Payments")
    end
  end

  it "flags an ongoing incident" do
    subscription = create(:subscription, user: user)
    create(:incident, :ongoing, feed: subscription.feed, title: "API outage", url: "https://stspg.io/x")

    get root_path

    card = card_for(subscription)
    expect(card.text).to include("Ongoing").and include("0").and include("API outage")
    expect(card.at_css("a[href='https://stspg.io/x']")).to be_present
  end

  it "warns when a status page can't be reached" do
    subscription = create(:subscription, user: user, feed: create(:feed, consecutive_failures: 2, last_error: "HTTP 503", last_success_at: 1.hour.ago))

    get root_path

    expect(card_for(subscription).text).to include("Can't reach this status page").and include("HTTP 503")
  end

  it "never shows other users' subscriptions" do
    others = create(:subscription, feed: create(:feed, name: "Someone Else's Feed"))

    get root_path

    expect(card_for(others)).to be_nil
    expect(response.body).not_to include("Someone Else's Feed")
  end
end

RSpec.describe "Dashboard live updates", :single_user_mode do
  it "subscribes the page to the user's refresh stream and morphs on refresh" do
    get root_path

    expect(response.body).to include("turbo-cable-stream-source")
    expect(response.body).to include('<meta name="turbo-refresh-method" content="morph">')
  end
end

RSpec.describe "Dashboard status page links", :single_user_mode do
  it "links each card's title to the service's real status page" do
    subscription = create(:subscription, user: SingleUserMode.user, feed: create(:feed, name: "GitHub", site_url: "https://www.githubstatus.com"))

    get root_path

    link = Nokogiri::HTML(response.body).at_css("##{ActionView::RecordIdentifier.dom_id(subscription)} h2 a")
    expect(link["href"]).to eq("https://www.githubstatus.com")
    expect(link["target"]).to eq("_blank")
  end

  it "shows a plain title when the status page URL is unknown" do
    subscription = create(:subscription, user: SingleUserMode.user, feed: create(:feed, name: "Mystery", site_url: nil))

    get root_path

    expect(Nokogiri::HTML(response.body).at_css("##{ActionView::RecordIdentifier.dom_id(subscription)} h2 a")).to be_nil
  end
end

RSpec.describe "Dashboard skipped-incident note", :single_user_mode do
  it "notes newer lower-severity incidents that didn't reset the counter" do
    travel_to Time.utc(2026, 11, 12) do
      subscription = create(:subscription, user: SingleUserMode.user, feed: create(:feed, name: "Huntress"))
      create(:incident, feed: subscription.feed, title: "SAT Performance Issues", impact: "major", started_at: Time.utc(2026, 11, 2, 19), resolved_at: Time.utc(2026, 11, 2, 20))
      create(:incident, feed: subscription.feed, title: "Delay in sending escalations", impact: "none", started_at: Time.utc(2026, 11, 3, 4), resolved_at: Time.utc(2026, 11, 3, 7))

      get root_path

      card = Nokogiri::HTML(response.body).at_css("##{ActionView::RecordIdentifier.dom_id(subscription)}").text.squish
      expect(card).to include("SAT Performance Issues")
      expect(card).to include("+1 lower-severity incident since, not counted")
    end
  end
end

RSpec.describe "Dashboard layouts", :single_user_mode do
  let(:user) { SingleUserMode.user }
  let!(:subscription) { create(:subscription, user: user, feed: create(:feed, name: "GitHub")) }

  def page = Nokogiri::HTML(response.body)

  it "shows cards by default" do
    get root_path

    expect(page.at_css("article##{ActionView::RecordIdentifier.dom_id(subscription)}")).to be_present
    expect(page.at_css("table")).to be_nil
  end

  it "switches to a compact list and remembers the choice" do
    create(:incident, :ongoing, feed: subscription.feed, title: "API outage")

    patch dashboard_layout_path, params: { layout: "list" }
    expect(response).to redirect_to(root_path)
    get root_path

    row = page.at_css("tr##{ActionView::RecordIdentifier.dom_id(subscription)}")
    expect(row.text.squish).to include("GitHub").and include("0").and include("Ongoing").and include("API outage")
    expect(user.reload).to be_dashboard_layout_list
  end

  it "switches back to cards" do
    user.update!(dashboard_layout: "list")

    patch dashboard_layout_path, params: { layout: "cards" }
    get root_path

    expect(page.at_css("article##{ActionView::RecordIdentifier.dom_id(subscription)}")).to be_present
  end

  it "rejects unknown layouts" do
    patch dashboard_layout_path, params: { layout: "carousel" }

    expect(flash[:alert]).to eq("Unknown dashboard layout.")
    expect(user.reload).to be_dashboard_layout_cards
  end
end

RSpec.describe "Dashboard stability levels", :single_user_mode do
  let(:user) { SingleUserMode.user }

  def subscription_resolved(days_ago, name)
    create(:subscription, user: user, feed: create(:feed, name: name)).tap do |subscription|
      create(:incident, feed: subscription.feed, impact: "major", started_at: days_ago.days.ago - 1.hour, resolved_at: days_ago.days.ago)
    end
  end

  def node(subscription) = Nokogiri::HTML(response.body).at_css("##{ActionView::RecordIdentifier.dom_id(subscription)}")

  it "labels each card with its level from the user's thresholds" do
    cards = { "day_one" => subscription_resolved(3, "A"), "short_streak" => subscription_resolved(14, "B"),
              "long_streak" => subscription_resolved(45, "C"), "solid_streak" => subscription_resolved(120, "D") }

    get root_path

    cards.each do |level, subscription|
      expect(node(subscription)["data-level"]).to eq(level)
      expect(node(subscription).at_css("[data-level-label]").text).to eq(Theme::DEFAULT_LEVEL_LABELS.fetch(level))
    end
  end

  it "makes a live incident pulse" do
    subscription = create(:subscription, user: user)
    create(:incident, :ongoing, feed: subscription.feed)

    get root_path

    expect(node(subscription)["data-level"]).to eq("ongoing")
    expect(node(subscription)["class"]).to include("ds-pulse")
  end

  it "shows levels in the list layout too" do
    user.update!(dashboard_layout: "list")
    subscription = subscription_resolved(14, "Slack")

    get root_path

    expect(node(subscription)["data-level"]).to eq("short_streak")
    expect(node(subscription).text).to include("Short streak")
  end
end

RSpec.describe "Dashboard live incident callouts", :single_user_mode do
  let(:user) { SingleUserMode.user }

  def page = Nokogiri::HTML(response.body)

  it "lists live incidents in a banner and counts them in the tab title" do
    %w[Cloudflare Slack].each do |name|
      create(:incident, :ongoing, feed: create(:subscription, user: user, feed: create(:feed, name: name)).feed)
    end
    create(:subscription, user: user, feed: create(:feed, name: "GitHub"))

    get root_path

    expect(page.at_css("#live_incidents").text.squish).to eq("⚠ 2 services have an incident in progress: Cloudflare and Slack")
    expect(page.at_css("title").text).to eq("(2) Dashboard · days-since")
  end

  it "shows no banner or count when everything is calm" do
    create(:subscription, user: user)

    get root_path

    expect(page.at_css("#live_incidents")).to be_nil
    expect(page.at_css("title").text).to eq("Dashboard · days-since")
  end
end

RSpec.describe "Dashboard level words follow the theme", :single_user_mode do
  it "uses the theme's words in the list layout too" do
    user = SingleUserMode.user
    user.update!(theme: "worksite", dashboard_layout: "list")
    subscription = create(:subscription, user: user)
    create(:incident, feed: subscription.feed, impact: "major", started_at: 3.days.ago - 1.hour, resolved_at: 3.days.ago)

    get root_path

    row = Nokogiri::HTML(response.body).at_css("##{ActionView::RecordIdentifier.dom_id(subscription)}")
    expect(row.at_css("[data-level-label]").text).to eq("Warning")
  end
end

RSpec.describe "Dashboard logos", :single_user_mode do
  it "shows each service's logo or monogram on cards and list rows" do
    user = SingleUserMode.user
    with_logo = create(:subscription, user: user, feed: create(:feed, name: "GitHub"))
    with_logo.feed.logo.attach(io: StringIO.new(file_fixture("logos/icon.png").binread), filename: "logo.png", content_type: "image/png")
    without = create(:subscription, user: user, feed: create(:feed, name: "Slack"))

    %w[cards list].each do |layout|
      user.update!(dashboard_layout: layout)
      get root_path
      page = Nokogiri::HTML(response.body)

      expect(page.at_css("##{ActionView::RecordIdentifier.dom_id(with_logo)} img[data-service-logo]")).to be_present
      expect(page.at_css("##{ActionView::RecordIdentifier.dom_id(without)} [data-service-logo='monogram']").text).to eq("S")
    end
  end
end

RSpec.describe "Logos in every theme", :single_user_mode do
  Theme.keys.each do |key|
    it "shows the logo or monogram on #{key} cards" do
      user = SingleUserMode.user
      user.update!(theme: key)
      with_logo = create(:subscription, user: user, feed: create(:feed, name: "GitHub"))
      with_logo.feed.logo.attach(io: StringIO.new(file_fixture("logos/icon.png").binread), filename: "logo.png", content_type: "image/png")
      without = create(:subscription, user: user, feed: create(:feed, name: "Slack"))

      get root_path

      page = Nokogiri::HTML(response.body)
      expect(page.at_css("##{ActionView::RecordIdentifier.dom_id(with_logo)} img[data-service-logo]")).to be_present
      expect(page.at_css("##{ActionView::RecordIdentifier.dom_id(without)} [data-service-logo='monogram']")).to be_present
    end
  end
end

RSpec.describe "Dashboard activity legend", :single_user_mode do
  let(:user) { SingleUserMode.user }

  before { create(:subscription, user: user) }

  it "explains the day colors in the default theme's card layout" do
    get root_path

    legend = Nokogiri::HTML(response.body).at_css("[data-activity-legend]")
    expect(legend.css("li").map { |item| item.text.strip }).to eq([ "Not tracked yet", "No incidents", "Minor", "Major", "Critical" ])
  end

  it "adds unknown severity only when an RSS incident shows up in the strip" do
    feed = create(:feed, :rss)
    create(:subscription, user: user, feed: feed)
    create(:incident, feed: feed, impact: "unknown", started_at: 2.days.ago, resolved_at: 2.days.ago)

    get root_path

    expect(Nokogiri::HTML(response.body).at_css("[data-activity-legend]").text).to include("Severity unknown")
  end

  it "is left out of the list layout and of themes that don't define one" do
    user.update!(dashboard_layout: "list")
    get root_path
    expect(response.body).not_to include("data-activity-legend")

    user.update!(dashboard_layout: "cards", theme: "github")
    get root_path
    expect(response.body).not_to include("data-activity-legend")
  end
end
