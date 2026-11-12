class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :subscriptions, dependent: :destroy
  has_many :feeds, through: :subscriptions

  enum :no_incident_display, { infinity: "infinity", since_tracking: "since_tracking" }, prefix: true, validate: true
  enum :dashboard_layout, { cards: "cards", list: "list" }, prefix: true, validate: true

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, uniqueness: true
  validates :default_min_severity, inclusion: { in: Severity::LEVELS }
  validates :theme, inclusion: { in: ->(_) { Theme.keys } }
  validate :time_zone_must_exist
  validates :short_streak_after_days, :long_streak_after_days, :solid_streak_after_days,
            numericality: { only_integer: true, greater_than: 0, less_than: 10_000 }
  validate :stability_thresholds_must_increase

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
    def stability_thresholds_must_increase
      return unless short_streak_after_days.is_a?(Integer) && long_streak_after_days.is_a?(Integer) && solid_streak_after_days.is_a?(Integer)
      return if short_streak_after_days < long_streak_after_days && long_streak_after_days < solid_streak_after_days

      errors.add(:base, "Streak thresholds must increase: short streak < long streak < solid streak")
    end

    def time_zone_must_exist
      errors.add(:time_zone, "is not a recognized time zone") unless ActiveSupport::TimeZone[time_zone.to_s]
    end
end
