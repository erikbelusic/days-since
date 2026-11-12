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
