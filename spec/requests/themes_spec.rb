require "rails_helper"

RSpec.describe "Themes" do
  it "marks the page with the user's theme", :single_user_mode do
    get root_path

    expect(response.body).to include('<html data-theme="default">')
  end

  it "uses the default theme on the sign-in page" do
    get new_session_path

    expect(response.body).to include('<html data-theme="default">')
  end
end
