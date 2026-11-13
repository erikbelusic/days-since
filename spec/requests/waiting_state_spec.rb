require "rails_helper"

# A feed that has never been polled has no data yet: every theme must say so
# instead of claiming "no incidents on record" (∞) or a streak.
RSpec.describe "Waiting for a feed's first update", :single_user_mode do
  let(:user) { SingleUserMode.user }

  Theme.all.each do |theme|
    it "shows the waiting state in the #{theme.name} theme" do
      user.update!(theme: theme.key, no_incident_display: "infinity")
      subscription = create(:subscription, user: user, feed: create(:feed, name: "Vercel", last_success_at: nil))

      get root_path

      card = Nokogiri::HTML(response.body).at_css("##{ActionView::RecordIdentifier.dom_id(subscription)}")
      expect(card["data-level"]).to eq("waiting")
      expect(card.at_css("[data-level-label]").text.strip).to eq(theme.level_label("waiting"))
      expect(card.text).not_to include("∞")
      expect(card.at_css("[data-days]").text).not_to match(/\d/)
    end
  end

  it "shows the waiting state in the list layout" do
    user.update!(dashboard_layout: "list", no_incident_display: "infinity")
    subscription = create(:subscription, user: user, feed: create(:feed, last_success_at: nil))

    get root_path

    row = Nokogiri::HTML(response.body).at_css("##{ActionView::RecordIdentifier.dom_id(subscription)}")
    expect(row["data-level"]).to eq("waiting")
    expect(row.text).not_to include("∞")
  end
end
