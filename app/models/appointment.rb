class Appointment < ApplicationRecord
  belongs_to :client
  belongs_to :provider
  belongs_to :availability
  
  validates :starts_at, :ends_at, :duration_minutes, :status, presence: true
  validates :duration_minutes, numericality: { greater_than: 0 }
  validates :status, inclusion: { in: %w[scheduled confirmed cancelled] }
  validate :ends_at_after_starts_at
  validate :duration_matches_time_range
  validate :appointment_within_availability_window
  validate :no_overlapping_appointments
  
  scope :active, -> { where.not(status: 'cancelled') }
  scope :for_provider, ->(provider_id) { where(provider_id: provider_id) }
  scope :between, ->(start_time, end_time) { where("starts_at < ? AND ends_at > ?", end_time, start_time) }
  
  def cancel!
    update!(status: 'cancelled')
  end
  
  def cancelled?
    status == 'cancelled'
  end
  
  private
  
  def ends_at_after_starts_at
    return unless starts_at && ends_at
    
    errors.add(:ends_at, "must be after start time") if ends_at <= starts_at
  end
  
  def duration_matches_time_range
    return unless starts_at && ends_at && duration_minutes
    
    calculated_duration = ((ends_at - starts_at) / 1.minute).round
    errors.add(:duration_minutes, "must match the time range") if duration_minutes != calculated_duration
  end
  
  def appointment_within_availability_window
    return unless availability && starts_at && ends_at
    
    unless availability.contains_time_range?(starts_at, ends_at)
      errors.add(:base, "appointment must be within the availability window")
    end
  end
  
  def no_overlapping_appointments
    return unless provider && starts_at && ends_at
    
    overlapping = provider.appointments
                         .where.not(id: id)
                         .where.not(status: 'cancelled')
                         .where("(starts_at < ? AND ends_at > ?) OR (starts_at < ? AND ends_at > ?) OR (starts_at >= ? AND ends_at <= ?)",
                                ends_at, starts_at, starts_at, ends_at, starts_at, ends_at)
    
    if overlapping.exists?
      errors.add(:base, "appointment conflicts with existing appointments")
    end
  end
end
