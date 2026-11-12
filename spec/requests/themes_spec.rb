require "rails_helper"

RSpec.describe "Themes" do
  it "marks the page with the user's theme", :single_user_mode do
    get root_path

    expect(response.body).to include('<body class="min-h-screen" data-theme="default">')
  end

  it "uses the default theme on the sign-in page" do
    get new_session_path

    expect(response.body).to include('<body class="min-h-screen" data-theme="default">')
  end
end

RSpec.describe "Theme picker", :single_user_mode do
  let(:user) { SingleUserMode.user }

  it "is in the navigation bar on every signed-in page" do
    get root_path

    nav = Nokogiri::HTML(response.body).at_css("header nav")
    expect(nav.at_css("select[name='theme'] option[selected]")["value"]).to eq("default")
  end

  it "is no longer part of the settings form" do
    get edit_settings_path

    expect(Nokogiri::HTML(response.body).at_css("main input[name='user[theme]']")).to be_nil
  end

  it "saves the chosen theme and returns to the same page" do
    patch theme_path, params: { theme: "default" }, headers: { "Referer" => edit_settings_url }

    expect(response).to redirect_to(edit_settings_url)
    expect(user.reload.theme).to eq("default")
  end

  it "rejects unknown themes" do
    patch theme_path, params: { theme: "neon" }

    expect(flash[:alert]).to eq("Unknown theme.")
    expect(user.reload.theme).to eq("default")
  end

  it "is hidden on the sign-in page", single_user_mode: false do
    get new_session_path

    expect(response.body).not_to include('name="theme"')
  end
end
