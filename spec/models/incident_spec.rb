require "rails_helper"

RSpec.describe Incident do
  it "keeps external ids unique within a feed but not across feeds" do
    feed = create(:feed)
    create(:incident, feed: feed, external_id: "abc")

    expect(build(:incident, feed: feed, external_id: "abc")).not_to be_valid
    expect(build(:incident, feed: create(:feed), external_id: "abc")).to be_valid
  end

  it "rejects impacts outside the known levels" do
    expect(build(:incident, impact: "apocalyptic")).not_to be_valid
    expect(build(:incident, impact: "unknown")).to be_valid
  end

  it "filters to incidents at or above a minimum severity, always including unknown" do
    feed = create(:feed)
    impacts = %w[none minor major critical unknown].index_with { |impact| create(:incident, feed: feed, impact: impact) }

    expect(feed.incidents.at_least("major")).to contain_exactly(impacts["major"], impacts["critical"], impacts["unknown"])
    expect(feed.incidents.at_least("none").count).to eq(5)
  end

  it "distinguishes ongoing from resolved incidents" do
    ongoing = create(:incident, :ongoing)
    resolved = create(:incident)

    expect(Incident.ongoing).to contain_exactly(ongoing)
    expect(Incident.resolved).to contain_exactly(resolved)
    expect(ongoing).to be_ongoing
  end

  it "is removed along with its feed" do
    incident = create(:incident)

    incident.feed.destroy

    expect(Incident.exists?(incident.id)).to be(false)
  end
end
