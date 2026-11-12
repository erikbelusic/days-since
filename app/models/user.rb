class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy

  enum :no_incident_display, { infinity: "infinity", since_tracking: "since_tracking" }, prefix: true, validate: true

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, uniqueness: true
  validates :default_min_severity, inclusion: { in: Severity::LEVELS }
  validate :time_zone_must_exist

  # Accounts are created by an admin (there is no public sign-up). Returns the
  # new user and the password that was set, generating one when none is given.
  def self.provision!(email_address:, password: nil)
    password = SecureRandom.base58(20) if password.blank?
    user = create!(email_address: email_address, password: password)
    [ user, password ]
  end

  def zone
    ActiveSupport::TimeZone[time_zone] || ActiveSupport::TimeZone["UTC"]
  end

  private
    def time_zone_must_exist
      errors.add(:time_zone, "is not a recognized time zone") unless ActiveSupport::TimeZone[time_zone.to_s]
    end
end
