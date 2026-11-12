require "rails_helper"

RSpec.describe Stability do
  let(:user) { build(:user, recovering_after_days: 7, stable_after_days: 30, rock_solid_after_days: 90) }

  def result(state: :counting, days: 0)
    DaysSinceCounter::Result.new(state: state, days: days, incident: nil, min_severity: "minor", ignored_count: 0, activity: [], level: nil)
  end

  it "maps day counts onto the user's thresholds" do
    expected = { 0 => "unstable", 6 => "unstable", 7 => "recovering", 29 => "recovering",
                 30 => "stable", 89 => "stable", 90 => "rock_solid", 400 => "rock_solid" }

    expect(expected.keys.index_with { |days| described_class.level(result(days: days), user) }).to eq(expected)
  end

  it "always reports a live incident as ongoing" do
    expect(described_class.level(result(state: :ongoing, days: 0), user)).to eq("ongoing")
  end

  it "treats no incidents on record as stable" do
    expect(described_class.level(result(state: :no_history, days: nil), user)).to eq("stable")
  end

  it "uses days since tracking started like any other count" do
    expect(described_class.level(result(state: :no_history, days: 120), user)).to eq("rock_solid")
  end

  it "follows custom thresholds" do
    user.assign_attributes(recovering_after_days: 2, stable_after_days: 5, rock_solid_after_days: 10)

    expect([ 1, 2, 5, 10 ].map { |days| described_class.level(result(days: days), user) })
      .to eq(%w[unstable recovering stable rock_solid])
  end
end
