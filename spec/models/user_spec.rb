require "rails_helper"

RSpec.describe User do
  it "stores email addresses stripped and downcased" do
    user = create(:user, email_address: "  Someone@Example.COM ")

    expect(user.reload.email_address).to eq("someone@example.com")
  end

  it "authenticates with a case-insensitive email address" do
    user = create(:user, email_address: "someone@example.com", password: "s3cret-pass")

    expect(User.authenticate_by(email_address: "SOMEONE@example.com", password: "s3cret-pass")).to eq(user)
  end
end

RSpec.describe User, "preferences" do
  it "defaults to UTC, minor severity, and the infinity display" do
    user = create(:user)

    expect(user.time_zone).to eq("UTC")
    expect(user.default_min_severity).to eq("minor")
    expect(user).to be_no_incident_display_infinity
  end

  it "accepts Rails and IANA time zone names" do
    expect(build(:user, time_zone: "Eastern Time (US & Canada)")).to be_valid
    expect(build(:user, time_zone: "America/Chicago")).to be_valid
  end

  it "rejects unknown time zones" do
    user = build(:user, time_zone: "Mars/Olympus_Mons")

    expect(user).not_to be_valid
    expect(user.errors[:time_zone]).to be_present
  end

  it "rejects unknown severities and display modes" do
    expect(build(:user, default_min_severity: "catastrophic")).not_to be_valid
    expect(build(:user, no_incident_display: "sparkles")).not_to be_valid
  end

  it "exposes its time zone for date math" do
    user = build(:user, time_zone: "America/Chicago")

    travel_to Time.utc(2026, 3, 1, 3, 0) do
      expect(user.zone.today).to eq(Date.new(2026, 2, 28))
    end
  end
end

RSpec.describe User, "theme" do
  it "defaults to the default theme and only accepts registered themes" do
    expect(create(:user).theme).to eq("default")
    expect(build(:user, theme: "not-a-theme")).not_to be_valid
  end
end

RSpec.describe User, "stability thresholds" do
  it "defaults to 7, 30, and 90 days" do
    expect(create(:user)).to have_attributes(short_streak_after_days: 7, long_streak_after_days: 30, solid_streak_after_days: 90)
  end

  it "requires positive whole numbers that increase" do
    expect(build(:user, short_streak_after_days: 0)).not_to be_valid
    expect(build(:user, long_streak_after_days: 2.5)).not_to be_valid
    expect(build(:user, short_streak_after_days: 30, long_streak_after_days: 30)).not_to be_valid
    expect(build(:user, long_streak_after_days: 100, solid_streak_after_days: 90)).not_to be_valid
    expect(build(:user, short_streak_after_days: 1, long_streak_after_days: 2, solid_streak_after_days: 3)).to be_valid
  end
end
