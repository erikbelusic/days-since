require "rails_helper"

RSpec.describe "Switching themes", :js, :single_user_mode do
  def computed(property, selector = "body")
    page.evaluate_script("getComputedStyle(document.querySelector(#{selector.to_json})).getPropertyValue(#{property.to_json}).trim()")
  end

  it "restyles the whole page immediately, without a manual refresh" do
    create(:subscription, user: SingleUserMode.user, feed: create(:feed, name: "GitHub"))

    visit root_path
    page.execute_script("window.__sameDocument = true")
    expect(computed("--ds-surface")).not_to eq("#f5c400")

    select "Worksite Safety Sign", from: "Theme"

    expect(page).to have_css("body[data-theme='worksite']")
    expect(page).to have_css("article.ws-hazard")
    expect(computed("--ds-surface")).to eq("#f5c400")
    expect(computed("font-family", "h2")).to include("Bebas Neue")
    expect(page.evaluate_script("window.__sameDocument")).to be(true) # Turbo swap, not a full reload

    select "Default", from: "Theme"

    expect(page).to have_css("body[data-theme='default']")
    expect(page).to have_no_css("article.ws-hazard")
    expect(computed("--ds-surface")).not_to eq("#f5c400")
  end
end
