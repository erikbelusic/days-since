require "rails_helper"

RSpec.describe SingleUserMode do
  describe ".warn_if_production" do
    let(:logger) { instance_double(Logger, warn: nil) }
    let(:io) { StringIO.new }

    it "warns loudly when enabled in production", :single_user_mode do
      described_class.warn_if_production(env: ActiveSupport::EnvironmentInquirer.new("production"), logger: logger, io: io)

      expect(logger).to have_received(:warn).with(/SINGLE_USER_MODE is enabled in production/)
      expect(io.string).to include("WARNING")
    end

    it "stays quiet in development", :single_user_mode do
      described_class.warn_if_production(env: ActiveSupport::EnvironmentInquirer.new("development"), logger: logger, io: io)

      expect(io.string).to be_empty
    end

    it "stays quiet in production when the mode is off" do
      described_class.warn_if_production(env: ActiveSupport::EnvironmentInquirer.new("production"), logger: logger, io: io)

      expect(io.string).to be_empty
    end
  end
end
