class PendingCommand < ApplicationRecord
  belongs_to :smartphone
  
  enum status: { pending: 0, processing: 1, completed: 2, failed: 3, timeout: 4 }
  
  # params and response_data are native json columns — no serialize needed
  
  validates :request_id, presence: true, uniqueness: true
  validates :command, presence: true
  
  scope :active, -> { where(status: [:pending, :processing]) }
  scope :expired, -> { where('created_at < ?', 5.minutes.ago).where(status: [:pending, :processing]) }
  
  after_create :schedule_timeout
  
  def mark_completed(response)
    update!(
      status: :completed,
      response_data: response,
      completed_at: Time.current
    )
  end
  
  def mark_failed(error_message)
    update!(
      status: :failed,
      response_data: { error: error_message },
      completed_at: Time.current
    )
  end
  
  private
  
  def schedule_timeout
    TimeoutCommandJob.set(wait: 5.minutes).perform_later(id)
  end
end
