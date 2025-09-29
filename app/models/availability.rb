class Availability < ApplicationRecord
  belongs_to :provider
  has_many :appointments, dependent: :destroy
  
  validates :external_id, presence: true, uniqueness: true
  validates :starts_at, :ends_at, :source, presence: true
  validate :ends_at_after_starts_at
  
  scope :available_between, ->(start_time, end_time) { where(starts_at: start_time..end_time).or(where(ends_at: start_time..end_time)).or(where("starts_at <= ? AND ends_at >= ?", start_time, end_time)) }
  scope :for_provider, ->(provider_id) { where(provider_id: provider_id) }
  
  # Check if this availability window has any conflicting appointments
  def available_for_appointment?(start_time, end_time)
    return false unless contains_time_range?(start_time, end_time)
    
    !appointments.where(status: ['scheduled', 'confirmed'])
                 .where("(starts_at < ? AND ends_at > ?) OR (starts_at < ? AND ends_at > ?) OR (starts_at >= ? AND ends_at <= ?)",
                        end_time, start_time, start_time, end_time, start_time, end_time)
                 .exists?
  end
  
  # Check if this availability window contains the given time range
  def contains_time_range?(start_time, end_time)
    starts_at <= start_time && ends_at >= end_time
  end
  
  private
  
  def ends_at_after_starts_at
    return unless starts_at && ends_at
    
    errors.add(:ends_at, "must be after start time") if ends_at <= starts_at
  end
end
