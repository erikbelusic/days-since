require "rails_helper"

RSpec.describe "Datadog-inspired theme", :single_user_mode do
  let(:user) { SingleUserMode.user.tap { |u| u.update!(theme: "datadog", time_zone: "UTC") } }

  it "renders metric tiles with monitor badges and 28-day bars" do
    travel_to Time.utc(2026, 3, 28, 12) do
      healthy = create(:subscription, user: user, feed: create(:feed, name: "GitHub"))
      create(:incident, feed: healthy.feed, impact: "major", started_at: Time.utc(2026, 3, 27, 9), resolved_at: Time.utc(2026, 3, 27, 10))
      ongoing = create(:subscription, user: user, feed: create(:feed, name: "Cloudflare"))
      create(:incident, :ongoing, feed: ongoing.feed, title: "DNS trouble")
      quiet = create(:subscription, user: user, feed: create(:feed, name: "Quiet Co"))

      visit root_path

      expect(page).to have_css("body[data-theme='datadog'] header.dd-nav")

      within("##{ActionView::RecordIdentifier.dom_id(healthy)}.dd-tile-ok") do
        expect(page).to have_css("[data-monitor-status]", text: "OK")
        expect(page).to have_text("days_since{service:github}")
        expect(page).to have_css("[data-days]", text: "1")
        expect(page).to have_text("day")
        expect(page).to have_css("[data-activity-bars] .dd-bar", count: 1)
        expect(page).to have_css("[data-activity-bars] span", count: 28)
      end

      within("##{ActionView::RecordIdentifier.dom_id(ongoing)}.dd-tile-alert") do
        expect(page).to have_css("[data-monitor-status]", text: "Alert")
        expect(page).to have_text("TRIGGERED DNS trouble")
      end

      within("##{ActionView::RecordIdentifier.dom_id(quiet)}.dd-tile-nodata") do
        expect(page).to have_css("[data-monitor-status]", text: "No data")
        expect(page).to have_css("[data-days]", text: "∞")
      end
    end
  end
end
