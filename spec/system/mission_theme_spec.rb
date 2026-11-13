require "rails_helper"

RSpec.describe "Mission Control theme", :single_user_mode do
  let(:user) { SingleUserMode.user.tap { |u| u.update!(theme: "mission", time_zone: "UTC") } }

  it "lights the annunciator lamp for each service's level" do
    travel_to Time.utc(2026, 3, 28, 12) do
      words = { nil => "Abort", 3 => "Hold", 14 => "Go", 45 => "Nominal", 120 => "All systems go" }
      subscriptions = words.keys.to_h do |days|
        sub = create(:subscription, user: user)
        if days
          create(:incident, feed: sub.feed, impact: "major", title: "Outage", started_at: days.days.ago - 1.hour, resolved_at: days.days.ago)
        else
          create(:incident, :ongoing, feed: sub.feed)
        end
        [ days, sub ]
      end

      visit root_path

      expect(page).to have_css("body[data-theme='mission']")
      words.each do |days, word|
        card = "##{ActionView::RecordIdentifier.dom_id(subscriptions[days])}"
        expect(page).to have_css("#{card} [data-level-label]", exact_text: word)
        expect(page).to have_css("#{card} [role=listitem]", count: 5)
      end
      expect(page).to have_css("##{ActionView::RecordIdentifier.dom_id(subscriptions[3])} [data-days][aria-label='3 days']")
      expect(page).to have_css("##{ActionView::RecordIdentifier.dom_id(subscriptions[3])}", text: "LAST ANOMALY Outage MAR 25")
      expect(page).to have_css("##{ActionView::RecordIdentifier.dom_id(subscriptions[nil])} .mc-blink[data-level-label]")
    end
  end

  it "reads out dashes for a service with no incidents on record" do
    user.update!(no_incident_display: "infinity")
    create(:subscription, user: user)

    visit root_path

    expect(page).to have_css("[data-days][aria-label='No anomalies on record']")
    expect(page).to have_css("article", text: /No anomalies on record/i)
  end
end
