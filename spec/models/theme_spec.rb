require "rails_helper"

RSpec.describe Theme do
  it "includes the default theme" do
    expect(described_class.default).to have_attributes(key: "default", name: "Default")
  end

  it "has unique keys" do
    expect(described_class.keys).to eq(described_class.keys.uniq)
  end

  it "falls back to the default theme for unknown keys" do
    expect(described_class.find("nope")).to be_nil
    expect(described_class.find_or_default("nope")).to eq(described_class.default)
  end

  it "ships a stylesheet for every registered theme" do
    described_class.all.each do |theme|
      css = Rails.root.join("app/assets/tailwind/themes/#{theme.key}.css")
      expect(css).to exist
      expect(Rails.root.join("app/assets/tailwind/application.css").read).to include(%(@import "./themes/#{theme.key}.css"))
    end
  end
end

RSpec.describe Theme, "level labels" do
  it "names every stability level, falling back to the default words" do
    Theme.all.each do |theme|
      Stability::LEVELS.each do |level|
        expect(theme.level_label(level)).to be_present
      end
    end
  end

  it "lets a theme use its own words" do
    expect(Theme.find("worksite").level_label("day_one")).to eq("Warning")
    expect(Theme.find("farmhouse").level_label("solid_streak")).to eq("Solid ground")
    expect(Theme.default.level_label("short_streak")).to eq("Short streak")
  end

  it "only labels known levels" do
    Theme.all.each do |theme|
      expect(theme.level_labels.keys - Stability::LEVELS).to be_empty
    end
  end
end
