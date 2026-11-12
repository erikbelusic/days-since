require "rails_helper"

RSpec.describe "Little Garden theme", :single_user_mode do
  let(:user) { SingleUserMode.user.tap { |u| u.update!(theme: "garden") } }

  it "grows a plant for the streak and brings a storm for live incidents" do
    words = { nil => "Storm's here", 3 => "Just planted", 14 => "Sprouting", 45 => "In bloom", 120 => "Mighty oak" }
    subscriptions = words.keys.to_h do |days|
      sub = create(:subscription, user: user)
      if days
        create(:incident, feed: sub.feed, impact: "major", started_at: days.days.ago - 1.hour, resolved_at: days.days.ago)
      else
        create(:incident, :ongoing, feed: sub.feed, title: "Rain on the parade")
      end
      [ days, sub ]
    end

    visit root_path

    expect(page).to have_css("body[data-theme='garden'] header.gd-header")
    words.each do |days, word|
      card = "##{ActionView::RecordIdentifier.dom_id(subscriptions[days])}"
      expect(page).to have_css("#{card} [data-level-label]", exact_text: word)
      expect(page).to have_css("#{card} [data-garden-scene]")
    end

    storm = "##{ActionView::RecordIdentifier.dom_id(subscriptions[nil])}"
    expect(page).to have_css("#{storm} .gd-sky-storm")
    expect(page).to have_css("#{storm}", text: "Rain on the parade")
    expect(page).to have_css("##{ActionView::RecordIdentifier.dom_id(subscriptions[45])} [data-days]", text: "45")
  end
end
