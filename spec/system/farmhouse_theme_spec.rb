require "rails_helper"

RSpec.describe "Farmhouse theme", :single_user_mode do
  let(:user) { SingleUserMode.user.tap { |u| u.update!(theme: "farmhouse") } }

  it "hangs one flip card per digit for counting, ongoing, and no-history states" do
    travel_to Time.utc(2026, 3, 10, 12) do
      counting = create(:subscription, user: user, feed: create(:feed, name: "GitHub"))
      create(:incident, feed: counting.feed, impact: "major", started_at: Time.utc(2025, 12, 1), resolved_at: Time.utc(2025, 12, 1, 1))
      ongoing = create(:subscription, user: user, feed: create(:feed, name: "Cloudflare"))
      create(:incident, :ongoing, feed: ongoing.feed, title: "DNS trouble")
      quiet = create(:subscription, user: user, feed: create(:feed, name: "Quiet Co"))

      visit root_path

      expect(page).to have_css("body[data-theme='farmhouse'] header.fh-header")

      within("##{ActionView::RecordIdentifier.dom_id(counting)}.fh-wood") do
        expect(all(".fh-flip").map(&:text)).to eq(%w[0 9 9])
        expect(page).to have_css("[data-days][aria-label='99 days']")
        expect(page).to have_text("Days since last incident")
      end

      within("##{ActionView::RecordIdentifier.dom_id(ongoing)}") do
        expect(all(".fh-flip.fh-flip-ongoing").map(&:text)).to eq(%w[0 0 0])
        expect(page).to have_text("Incident in progress")
        expect(page).to have_text("DNS trouble")
      end

      within("##{ActionView::RecordIdentifier.dom_id(quiet)}") do
        expect(all(".fh-flip").map(&:text)).to eq([ "∞" ])
        expect(page).to have_text("No incidents on record")
      end
    end
  end
end
