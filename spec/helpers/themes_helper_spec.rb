require "rails_helper"

RSpec.describe ThemesHelper do
  let(:fancy) { Theme.new(key: "fancy", name: "Fancy", description: "") }

  it "uses the default theme when nobody is signed in" do
    expect(helper.current_theme).to eq(Theme.default)
  end

  it "uses the current user's theme" do
    Current.single_user = build(:user, theme: "default")

    expect(helper.current_theme.key).to eq("default")
  end

  it "renders a theme's own partial when it has one" do
    allow(helper.lookup_context).to receive(:exists?).with("feed_card", [ "themes/fancy" ], true).and_return(true)

    expect(helper.themed_partial("feed_card", theme: fancy)).to eq("themes/fancy/feed_card")
  end

  it "falls back to the default theme's partial" do
    allow(helper.lookup_context).to receive(:exists?).with("feed_card", [ "themes/fancy" ], true).and_return(false)

    expect(helper.themed_partial("feed_card", theme: fancy)).to eq("themes/default/feed_card")
  end
end
