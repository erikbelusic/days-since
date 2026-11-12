require "rails_helper"

RSpec.describe "Arcade theme", :single_user_mode do
  let(:user) { SingleUserMode.user.tap { |u| u.update!(theme: "arcade") } }

  it "shows the streak as a score with lives and game-state words" do
    words = { nil => [ "Game over", 0 ], 3 => [ "Press start", 1 ], 14 => [ "Level up", 2 ], 45 => [ "Combo!", 3 ], 120 => [ "High score!", 3 ] }
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

    expect(page).to have_css("body[data-theme='arcade']")
    words.each do |days, (word, lives)|
      card = "##{ActionView::RecordIdentifier.dom_id(subscriptions[days])}"
      expect(page).to have_css("#{card} [data-level-label]", exact_text: word)
      expect(page).to have_css("#{card} [aria-label='#{lives} of 3 lives']")
    end
    expect(page).to have_css("##{ActionView::RecordIdentifier.dom_id(subscriptions[45])} [data-days]", text: "000045")
    expect(page).to have_css("##{ActionView::RecordIdentifier.dom_id(subscriptions[nil])} .ar-blink[data-level-label]")
  end
end
