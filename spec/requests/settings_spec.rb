require "rails_helper"

RSpec.describe "Settings", :single_user_mode do
  let(:user) { SingleUserMode.user }

  it "is linked from the header" do
    get root_path

    expect(response.body).to include(edit_settings_path)
  end

  it "shows the current preferences" do
    user.update!(time_zone: "Central Time (US & Canada)", no_incident_display: "since_tracking")

    get edit_settings_path

    page = Nokogiri::HTML(response.body)
    expect(page.at_css("select#user_time_zone option[selected]")["value"]).to eq("Central Time (US & Canada)")
    expect(page.at_css("input#user_no_incident_display_since_tracking")["checked"]).to be_present
  end

  it "saves time zone, default severity, and no-incident display" do
    patch settings_path, params: { user: { time_zone: "Pacific Time (US & Canada)", default_min_severity: "major", no_incident_display: "since_tracking" } }

    expect(response).to redirect_to(root_path)
    expect(user.reload).to have_attributes(time_zone: "Pacific Time (US & Canada)", default_min_severity: "major", no_incident_display: "since_tracking")
  end

  it "rejects invalid values" do
    patch settings_path, params: { user: { time_zone: "Nowhere/Land" } }

    expect(response).to have_http_status(:unprocessable_content)
    expect(user.reload.time_zone).to eq("UTC")
  end

  it "ignores attempts to change the email address" do
    patch settings_path, params: { user: { email_address: "evil@example.com", time_zone: "UTC" } }

    expect(user.reload.email_address).to eq(SingleUserMode::LOCAL_EMAIL_ADDRESS)
  end

  it "changes the dashboard counts to the new default severity" do
    subscription = create(:subscription, user: user)
    create(:incident, :ongoing, feed: subscription.feed, impact: "minor")

    patch settings_path, params: { user: { default_min_severity: "major" } }
    get root_path

    expect(response.body).not_to include("Ongoing")
  end
end
