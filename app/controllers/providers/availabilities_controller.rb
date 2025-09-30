module Providers
  class AvailabilitiesController < ApplicationController
    before_action :find_provider
    before_action :validate_date_params, only: [ :index ]

    # GET /providers/:provider_id/availabilities?from=<datetime>&to=<datetime>
    # Returns available time slots for a provider within the specified time range
    def index
      availabilities = @provider.availabilities
                                .available_between(@from_time, @to_time)
                                .includes(:appointments)
                                .order(:starts_at)

      # Filter out fully booked availability windows
      available_slots = availabilities.select do |availability|
        has_free_time?(availability)
      end

      render json: {
        provider_id: @provider.id,
        provider_name: @provider.name,
        from: @from_time.iso8601,
        to: @to_time.iso8601,
        availabilities: available_slots.map { |availability| format_availability(availability) }
      }
    end

    private

    def find_provider
      @provider = Provider.find(params[:provider_id])
    rescue ActiveRecord::RecordNotFound
      render json: { error: "Provider not found" }, status: :not_found
    end

    def validate_date_params
      unless params[:from] && params[:to]
        render json: { error: "Both from and to parameters are required" }, status: :bad_request
        return
      end

      begin
        @from_time = Time.parse(params[:from])
        @to_time = Time.parse(params[:to])
      rescue ArgumentError
        render json: { error: "Invalid date format. Use ISO8601 format (e.g., 2023-10-15T09:00:00Z)" }, status: :bad_request
        return
      end

      if @from_time >= @to_time
        render json: { error: "From time must be before to time" }, status: :bad_request
        nil
      end
    end

    def has_free_time?(availability)
      # Check if there's any free time in this availability window
      active_appointments = availability.appointments.where.not(status: "cancelled")
                                       .where("starts_at < ? AND ends_at > ?", @to_time, @from_time)
                                       .order(:starts_at)

      # If no appointments, the whole window is free
      return true if active_appointments.empty?

      # Check for gaps between appointments or before/after appointments
      window_start = [ @from_time, availability.starts_at ].max
      window_end = [ @to_time, availability.ends_at ].min

      # Check if there's time before the first appointment
      first_appointment = active_appointments.first
      return true if first_appointment.starts_at > window_start

      # Check for gaps between appointments
      active_appointments.each_cons(2) do |current, next_appointment|
        return true if next_appointment.starts_at > current.ends_at
      end

      # Check if there's time after the last appointment
      last_appointment = active_appointments.last
      return true if last_appointment.ends_at < window_end

      false
    end

    def format_availability(availability)
      # Calculate available time slots within the requested window
      window_start = [ @from_time, availability.starts_at ].max
      window_end = [ @to_time, availability.ends_at ].min

      active_appointments = availability.appointments.where.not(status: "cancelled")
                                       .where("starts_at < ? AND ends_at > ?", window_end, window_start)
                                       .order(:starts_at)

      free_slots = calculate_free_slots(window_start, window_end, active_appointments)

      {
        id: availability.id,
        external_id: availability.external_id,
        starts_at: availability.starts_at.iso8601,
        ends_at: availability.ends_at.iso8601,
        source: availability.source,
        available_slots: free_slots,
        total_appointments: active_appointments.count
      }
    end

    def calculate_free_slots(window_start, window_end, appointments)
      free_slots = []
      current_time = window_start

      appointments.each do |appointment|
        # Add free slot before this appointment if there's a gap
        if appointment.starts_at > current_time
          free_slots << {
            starts_at: current_time.iso8601,
            ends_at: appointment.starts_at.iso8601,
            duration_minutes: ((appointment.starts_at - current_time) / 1.minute).round
          }
        end
        current_time = [ current_time, appointment.ends_at ].max
      end

      # Add remaining free time after all appointments
      if current_time < window_end
        free_slots << {
          starts_at: current_time.iso8601,
          ends_at: window_end.iso8601,
          duration_minutes: ((window_end - current_time) / 1.minute).round
        }
      end

      free_slots
    end
  end
end
