require "rails_helper"

RSpec.describe "Subscribing to a status page", :single_user_mode do
  it "adds the page from the dashboard and shows its card" do
    stub_statuspage_site("www.githubstatus.com")

    visit root_path
    click_on "Add status page"
    fill_in "Status page URL", with: "www.githubstatus.com"
    click_on "Add status page"

    expect(page).to have_text("Added GitHub.")
    expect(page).to have_css("article", text: "GitHub")
    expect(page).to have_text("Waiting for the first update")
  end
end
