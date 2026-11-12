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
