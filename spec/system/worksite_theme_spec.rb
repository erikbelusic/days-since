require "rails_helper"

RSpec.describe "Worksite Safety Sign theme", :single_user_mode do
  let(:user) { SingleUserMode.user.tap { |u| u.update!(theme: "worksite") } }

  it "renders the site-board cards for counting, ongoing, and no-history states" do
    travel_to Time.utc(2026, 3, 10, 12) do
      counting = create(:subscription, user: user, feed: create(:feed, name: "GitHub"))
      create(:incident, feed: counting.feed, impact: "major", started_at: Time.utc(2026, 3, 3), resolved_at: Time.utc(2026, 3, 3, 1))
      ongoing = create(:subscription, user: user, feed: create(:feed, name: "Cloudflare"))
      create(:incident, :ongoing, feed: ongoing.feed, title: "DNS trouble")
      quiet = create(:subscription, user: user, feed: create(:feed, name: "Quiet Co"))

      visit root_path

      expect(page).to have_css("body[data-theme='worksite']")
      expect(page).to have_css("header .ws-hazard-thin")

      within("##{ActionView::RecordIdentifier.dom_id(counting)}.ws-hazard") do
        expect(page).to have_css("[data-days]", text: "07")
        expect(page).to have_text("Days since last incident")
      end

      within("##{ActionView::RecordIdentifier.dom_id(ongoing)}.ws-hazard-red") do
        expect(page).to have_css("[data-days]", text: "00")
        expect(page).to have_text("Incident in progress")
        expect(page).to have_text("DNS trouble")
      end

      within("##{ActionView::RecordIdentifier.dom_id(quiet)}") do
        expect(page).to have_css("[data-days]", text: "∞")
        expect(page).to have_text("No incidents on record")
      end
    end
  end

  it "headlines each card with a safety-sign word for its stability level" do
    words = { nil => "Danger", 3 => "Warning", 14 => "Caution", 45 => "Safe", 120 => "★ Safety record ★" }
    subscriptions = words.keys.to_h do |days|
      sub = create(:subscription, user: user)
      if days
        create(:incident, feed: sub.feed, impact: "major", started_at: days.days.ago - 1.hour, resolved_at: days.days.ago)
      else
        create(:incident, :ongoing, feed: sub.feed)
      end
      [ days, sub ]
    end

    visit root_path

    words.each do |days, word|
      expect(page).to have_css("##{ActionView::RecordIdentifier.dom_id(subscriptions[days])} [data-level-label]", exact_text: word)
    end
  end

  it "can be chosen from the navigation bar" do
    SingleUserMode.user

    visit root_path
    select "Worksite Safety Sign", from: "Theme"
    click_on "Apply" if page.has_button?("Apply", wait: 0)

    expect(SingleUserMode.user.reload.theme).to eq("worksite")
  end
end
