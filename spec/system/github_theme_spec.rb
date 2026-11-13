require "rails_helper"

RSpec.describe "GitHub-inspired theme", :single_user_mode do
  let(:user) { SingleUserMode.user.tap { |u| u.update!(theme: "github", time_zone: "UTC") } }

  it "shows status labels and a 28-day contribution-style grid colored by severity" do
    travel_to Time.utc(2026, 3, 28, 12) do
      healthy = create(:subscription, user: user, feed: create(:feed, name: "GitHub"))
      create(:incident, feed: healthy.feed, impact: "major", started_at: Time.utc(2026, 3, 20, 9), resolved_at: Time.utc(2026, 3, 21, 9))
      ongoing = create(:subscription, user: user, feed: create(:feed, name: "Cloudflare"))
      create(:incident, :ongoing, feed: ongoing.feed, title: "DNS trouble", started_at: Time.utc(2026, 3, 28, 8))
      quiet = create(:subscription, user: user, feed: create(:feed, name: "Quiet Co"))

      visit root_path

      expect(page).to have_css("body[data-theme='github'] header.gh-header")

      within("##{ActionView::RecordIdentifier.dom_id(healthy)}") do
        expect(page).to have_css("[data-level-label]", exact_text: "Passing")
        expect(page).to have_css("[data-days]", text: "7")
        expect(page).to have_css("[data-activity-bars] .gh-cell", count: 28)
        expect(page).to have_css("[data-activity-bars] .gh-cell[data-day=major]", count: 2)
        expect(page).to have_css("[data-activity-bars][aria-label='2 days with incidents in the last 28 days']")
      end

      within("##{ActionView::RecordIdentifier.dom_id(ongoing)}") do
        expect(page).to have_css("[data-level-label]", exact_text: "Failing")
        expect(page).to have_text("DNS trouble")
        expect(page).to have_css("[data-activity-bars] .gh-cell:last-child[data-day=minor]")
      end

      within("##{ActionView::RecordIdentifier.dom_id(quiet)}") do
        expect(page).to have_css("[data-level-label]", exact_text: "Green")
        expect(page).to have_css("[data-days]", text: "∞")
      end
    end
  end
end
