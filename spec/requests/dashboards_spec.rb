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

      expect(card_for(github).text).to include("GitHub").and include("7").and include("days since last incident")
      expect(card_for(stripe).text).to include("Payments").and include("∞").and include("no incidents on record")
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

RSpec.describe "Dashboard counted-incident explanation", :single_user_mode do
  it "labels the counted incident with the threshold and notes skipped lower-severity incidents" do
    travel_to Time.utc(2026, 11, 12) do
      subscription = create(:subscription, user: SingleUserMode.user, feed: create(:feed, name: "Huntress"))
      create(:incident, feed: subscription.feed, title: "SAT Performance Issues", impact: "major", started_at: Time.utc(2026, 11, 2, 19), resolved_at: Time.utc(2026, 11, 2, 20))
      create(:incident, feed: subscription.feed, title: "Delay in sending escalations", impact: "none", started_at: Time.utc(2026, 11, 3, 4), resolved_at: Time.utc(2026, 11, 3, 7))

      get root_path

      card = Nokogiri::HTML(response.body).at_css("##{ActionView::RecordIdentifier.dom_id(subscription)}").text.squish
      expect(card).to include("Last counted (minor+): SAT Performance Issues")
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
