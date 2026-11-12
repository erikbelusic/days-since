# A user's personal view of a shared Feed: their name for it, their severity
# threshold, and where it sits on their dashboard.
class Subscription < ApplicationRecord
  belongs_to :user
  belongs_to :feed

  normalizes :display_name, :min_severity, with: ->(value) { value.strip.presence }

  validates :feed_id, uniqueness: { scope: :user_id, message: "is already on your dashboard" }
  validates :min_severity, inclusion: { in: Severity::LEVELS }, allow_nil: true

  before_create :append_to_end

  scope :ordered, -> { order(:position, :id) }

  def name
    display_name || feed.display_name
  end

  # The subscription's own threshold, or the user's default when unset.
  def effective_min_severity
    min_severity || user.default_min_severity
  end

  private
    def append_to_end
      self.position = (user.subscriptions.maximum(:position) || -1) + 1
    end
end
