# Audit record for one provider synchronization run.
#
# Never write a provider API key, an authenticated upstream URL, or raw
# upstream headers into `error_summary`.
class CatalogSyncRun < ApplicationRecord
  STATUSES = %w[running succeeded failed].freeze

  validates :source, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :started_at, presence: true

  scope :recent, -> { order(started_at: :desc) }
  scope :for_source, ->(source) { where(source: source) }

  def running?
    status == "running"
  end

  def finish!(status:, error_summary: nil)
    update!(status: status, finished_at: Time.current, error_summary: error_summary)
  end

  def duration_seconds
    return nil if started_at.blank? || finished_at.blank?

    finished_at - started_at
  end
end
