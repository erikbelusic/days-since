require "rails_helper"

RSpec.describe Severity do
  describe ".meets?" do
    it "counts impacts at or above the minimum" do
      expect(described_class.meets?("major", "minor")).to be(true)
      expect(described_class.meets?("minor", "minor")).to be(true)
      expect(described_class.meets?("none", "minor")).to be(false)
      expect(described_class.meets?("major", "critical")).to be(false)
    end

    it "counts everything when the minimum is none" do
      expect(described_class::LEVELS).to all(satisfy { |level| described_class.meets?(level, "none") })
    end

    it "always counts incidents with unknown severity" do
      expect(described_class.meets?("unknown", "critical")).to be(true)
      expect(described_class.meets?(nil, "critical")).to be(true)
    end
  end
end
