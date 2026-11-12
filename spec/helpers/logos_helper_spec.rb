require "rails_helper"

RSpec.describe LogosHelper do
  let(:subscription) { create(:subscription, feed: create(:feed, name: "github")) }

  it "shows the stored logo" do
    subscription.feed.logo.attach(io: StringIO.new(file_fixture("logos/icon.png").binread), filename: "logo.png", content_type: "image/png")

    html = Nokogiri::HTML.fragment(helper.service_logo(subscription))

    expect(html.at_css("img[data-service-logo]")["src"]).to include("logo.png")
    expect(html.at_css("img")["alt"]).to eq("")
  end

  it "falls back to a capitalized monogram" do
    html = Nokogiri::HTML.fragment(helper.service_logo(subscription))

    expect(html.at_css("[data-service-logo='monogram']").text).to eq("G")
  end

  it "uses the subscription's display name for the monogram" do
    subscription.update!(display_name: "Work Git")

    expect(Nokogiri::HTML.fragment(helper.service_logo(subscription)).text).to eq("W")
  end
end
