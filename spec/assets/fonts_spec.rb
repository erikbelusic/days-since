require "rails_helper"

RSpec.describe "Self-hosted fonts" do
  fonts = Rails.root.glob("app/assets/fonts/**/*.{ttf,otf,woff,woff2}")

  it "bundles at least one font" do
    expect(fonts).not_to be_empty
  end

  fonts.each do |font|
    it "ships an open-font license next to #{font.relative_path_from(Rails.root)}" do
      licenses = font.dirname.glob("*{OFL,LICENSE}*.txt")

      expect(licenses.map(&:read)).to include(a_string_including("Open Font License").or(a_string_including("Apache License")))
    end
  end

  it "declares every bundled font in fonts.css" do
    css = Rails.root.join("app/assets/tailwind/fonts.css").read

    fonts.each do |font|
      expect(css).to include("/#{font.relative_path_from(Rails.root.join("app/assets/fonts"))}")
    end
  end
end
