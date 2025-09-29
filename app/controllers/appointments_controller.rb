class AppointmentsController < ApplicationController
  before_action :find_appointment, only: [:destroy]
  
  # POST /appointments
  # Params: client_id, provider_id, starts_at, ends_at, duration_minutes (optional)
  def create
    begin
      appointment = create_appointment
      
      if appointment.persisted?
        render json: {
          id: appointment.id,
          client_id: appointment.client_id,
          provider_id: appointment.provider_id,
          availability_id: appointment.availability_id,
          starts_at: appointment.starts_at.iso8601,
          ends_at: appointment.ends_at.iso8601,
          duration_minutes: appointment.duration_minutes,
          status: appointment.status,
          created_at: appointment.created_at.iso8601
        }, status: :created
      else
        render json: { 
          error: 'Failed to create appointment', 
          details: appointment.errors.full_messages 
        }, status: :unprocessable_entity
      end
    rescue ActiveRecord::RecordNotFound => e
      render json: { error: e.message }, status: :not_found
    rescue ArgumentError => e
      render json: { error: e.message }, status: :bad_request
    rescue StandardError => e
      render json: { error: 'Internal server error', details: e.message }, status: :internal_server_error
    end
  end

  # DELETE /appointments/:id
  # Soft-cancels an appointment by marking it as cancelled
  def destroy
    if @appointment.cancel!
      render json: {
        id: @appointment.id,
        status: @appointment.status,
        cancelled_at: @appointment.updated_at.iso8601,
        message: 'Appointment successfully cancelled'
      }
    else
      render json: { 
        error: 'Failed to cancel appointment', 
        details: @appointment.errors.full_messages 
      }, status: :unprocessable_entity
    end
  rescue StandardError => e
    render json: { error: 'Internal server error', details: e.message }, status: :internal_server_error
  end

  private

  def find_appointment
    @appointment = Appointment.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Appointment not found' }, status: :not_found
  end

  def create_appointment
    # Validate required parameters
    validate_required_params!
    
    # Parse and validate datetime parameters
    starts_at, ends_at = parse_datetime_params
    
    # Find client and provider
    client = Client.find(params[:client_id])
    provider = Provider.find(params[:provider_id])
    
    # Calculate duration if not provided
    duration_minutes = params[:duration_minutes]&.to_i || calculate_duration(starts_at, ends_at)
    
    # Find suitable availability window
    availability = find_suitable_availability(provider, starts_at, ends_at)
    
    # Create the appointment
    Appointment.create!(
      client: client,
      provider: provider,
      availability: availability,
      starts_at: starts_at,
      ends_at: ends_at,
      duration_minutes: duration_minutes,
      status: 'scheduled'
    )
  end

  def validate_required_params!
    required_params = %w[client_id provider_id starts_at ends_at]
    missing_params = required_params.select { |param| params[param].blank? }
    
    if missing_params.any?
      raise ArgumentError, "Missing required parameters: #{missing_params.join(', ')}"
    end
  end

  def parse_datetime_params
    starts_at = Time.parse(params[:starts_at])
    ends_at = Time.parse(params[:ends_at])
    
    if starts_at >= ends_at
      raise ArgumentError, 'Start time must be before end time'
    end
    
    if starts_at < Time.current
      raise ArgumentError, 'Cannot book appointments in the past'
    end
    
    [starts_at, ends_at]
  rescue ArgumentError => e
    raise ArgumentError, "Invalid datetime format: #{e.message}"
  end

  def calculate_duration(starts_at, ends_at)
    ((ends_at - starts_at) / 1.minute).round
  end

  def find_suitable_availability(provider, starts_at, ends_at)
    # Find all availability windows that could contain this appointment
    potential_availabilities = provider.availabilities
                                      .where('starts_at <= ? AND ends_at >= ?', starts_at, ends_at)
                                      .includes(:appointments)
    
    if potential_availabilities.empty?
      raise ArgumentError, 'No availability window found for the requested time slot'
    end
    
    # Find the first availability that can accommodate the appointment
    suitable_availability = potential_availabilities.find do |availability|
      availability.available_for_appointment?(starts_at, ends_at)
    end
    
    unless suitable_availability
      raise ArgumentError, 'The requested time slot conflicts with existing appointments'
    end
    
    suitable_availability
  end
end
