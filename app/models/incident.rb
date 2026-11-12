class Incident < ApplicationRecord
  belongs_to :feed

  validates :external_id, presence: true, uniqueness: { scope: :feed_id }
  validates :title, :started_at, presence: true
  validates :impact, inclusion: { in: Severity::IMPACTS }

  scope :ongoing, -> { where(resolved_at: nil) }
  scope :resolved, -> { where.not(resolved_at: nil) }
  scope :at_least, ->(minimum) { where(impact: Severity.at_least(minimum)) }

  def ongoing?
    resolved_at.nil?
  end
end
