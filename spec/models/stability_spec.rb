require "rails_helper"

RSpec.describe Stability do
  let(:user) { build(:user, short_streak_after_days: 7, long_streak_after_days: 30, solid_streak_after_days: 90) }

  def result(state: :counting, days: 0)
    DaysSinceCounter::Result.new(state: state, days: days, incident: nil, min_severity: "minor", ignored_count: 0, activity: [], worst_impacts: [], tracked_since: nil, level: nil)
  end

  it "maps day counts onto the user's thresholds" do
    expected = { 0 => "day_one", 6 => "day_one", 7 => "short_streak", 29 => "short_streak",
                 30 => "long_streak", 89 => "long_streak", 90 => "solid_streak", 400 => "solid_streak" }

    expect(expected.keys.index_with { |days| described_class.level(result(days: days), user) }).to eq(expected)
  end

  it "reports a feed with no data yet as waiting, not as a streak" do
    expect(described_class.level(result(state: :waiting, days: nil), user)).to eq("waiting")
  end

  it "always reports a live incident as ongoing" do
    expect(described_class.level(result(state: :ongoing, days: 0), user)).to eq("ongoing")
  end

  it "treats no incidents on record as stable" do
    expect(described_class.level(result(state: :no_history, days: nil), user)).to eq("long_streak")
  end

  it "uses days since tracking started like any other count" do
    expect(described_class.level(result(state: :no_history, days: 120), user)).to eq("solid_streak")
  end

  it "follows custom thresholds" do
    user.assign_attributes(short_streak_after_days: 2, long_streak_after_days: 5, solid_streak_after_days: 10)

    expect([ 1, 2, 5, 10 ].map { |days| described_class.level(result(days: days), user) })
      .to eq(%w[day_one short_streak long_streak solid_streak])
  end
end
