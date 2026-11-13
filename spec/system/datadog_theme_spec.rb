require "rails_helper"

RSpec.describe "Datadog-inspired theme", :single_user_mode do
  let(:user) { SingleUserMode.user.tap { |u| u.update!(theme: "datadog", time_zone: "UTC") } }

  def tile(subscription) = "##{ActionView::RecordIdentifier.dom_id(subscription)}"

  it "renders metric tiles with monitor badges and 28-day bars" do
    travel_to Time.utc(2026, 3, 28, 12) do
      healthy = create(:subscription, user: user, feed: create(:feed, name: "GitHub"))
      create(:incident, feed: healthy.feed, impact: "major", started_at: Time.utc(2026, 3, 27, 9), resolved_at: Time.utc(2026, 3, 27, 10))
      ongoing = create(:subscription, user: user, feed: create(:feed, name: "Cloudflare"))
      create(:incident, :ongoing, feed: ongoing.feed, title: "DNS trouble")
      quiet = create(:subscription, user: user, feed: create(:feed, name: "Quiet Co"))

      visit root_path

      expect(page).to have_css("body[data-theme='datadog'] header.dd-nav")

      within("#{tile(healthy)}[data-level='day_one']") do
        expect(page).to have_css("[data-monitor-status]", exact_text: "Warn")
        expect(page).to have_text("days_since{service:github}")
        expect(page).to have_css("[data-days]", text: "1")
        expect(page).to have_css("[data-activity-bars] .dd-bar:not([data-day=clear]):not([data-day=untracked])", count: 1)
        expect(page).to have_css("[data-activity-bars] span", count: 28)
      end

      within("#{tile(ongoing)}[data-level='ongoing'].ds-pulse") do
        expect(page).to have_css("[data-monitor-status]", exact_text: "Alert")
        expect(page).to have_text("TRIGGERED DNS trouble")
      end

      within("#{tile(quiet)}[data-level='long_streak']") do
        expect(page).to have_css("[data-monitor-status]", exact_text: "OK")
        expect(page).to have_css("[data-days]", text: "∞")
      end
    end
  end

  it "uses monitor and SLO words for longer streaks" do
    { 14 => "Watch", 120 => "SLO met" }.each do |days, word|
      subscription = create(:subscription, user: user)
      create(:incident, feed: subscription.feed, impact: "major", started_at: days.days.ago - 1.hour, resolved_at: days.days.ago)

      visit root_path

      expect(page).to have_css("#{tile(subscription)} [data-monitor-status]", exact_text: word)
    end
  end
end
