require "rails_helper"

RSpec.describe "Swiss Report theme", :single_user_mode do
  let(:user) { SingleUserMode.user.tap { |u| u.update!(theme: "swiss", time_zone: "UTC") } }

  it "reports each service with a factual level label and the incident date" do
    travel_to Time.utc(2026, 3, 28, 12) do
      words = { nil => "Active incident", 3 => "Recent", 14 => "Moderate", 45 => "Established", 120 => "Sustained" }
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

      expect(page).to have_css("body[data-theme='swiss']")
      words.each do |days, word|
        expect(page).to have_css("##{ActionView::RecordIdentifier.dom_id(subscriptions[days])} [data-level-label]", exact_text: word)
      end
      expect(page).to have_css("##{ActionView::RecordIdentifier.dom_id(subscriptions[3])}", text: "2026-03-25 Outage")
      expect(page).to have_css("##{ActionView::RecordIdentifier.dom_id(subscriptions[14])}", text: "Days without an incident")
    end
  end
end
