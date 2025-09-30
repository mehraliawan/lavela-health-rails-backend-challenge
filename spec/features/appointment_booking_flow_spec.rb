require 'rails_helper'

RSpec.describe "Appointment Booking Flow", type: :request do
  describe "complete appointment booking flow" do
    let(:provider) { create(:provider, :dr_wilson) }
    let(:client) { create(:client, :jane_smith) }

    before do
      create(:availability, :full_day_slot, provider: provider)
    end

    it "allows checking availability and booking an appointment" do
      # Step 1: Check provider availability
      from_time = 4.days.from_now.beginning_of_day + 8.hours
      to_time = 4.days.from_now.beginning_of_day + 18.hours

      get provider_availabilities_path(provider), params: {
        from: from_time.iso8601,
        to: to_time.iso8601
      }

      expect(response).to have_http_status(:success)
      availability_response = JSON.parse(response.body)
      expect(availability_response["availabilities"].count).to be > 0

      # Step 2: Find an available slot
      availability = availability_response["availabilities"].first
      available_slot = availability["available_slots"].first

      expect(available_slot).not_to be_nil

      # Step 3: Book an appointment in that slot
      appointment_params = {
        client_id: client.id,
        provider_id: provider.id,
        starts_at: available_slot["starts_at"],
        ends_at: available_slot["ends_at"],
        duration_minutes: available_slot["duration_minutes"]
      }

      expect {
        post appointments_path, params: appointment_params
      }.to change { Appointment.count }.by(1)

      expect(response).to have_http_status(:created)
      appointment_response = JSON.parse(response.body)

      # Step 4: Verify appointment was created correctly
      expect(appointment_response["client_id"]).to eq(client.id)
      expect(appointment_response["provider_id"]).to eq(provider.id)
      expect(appointment_response["status"]).to eq("scheduled")
      expect(appointment_response["duration_minutes"]).to eq(available_slot["duration_minutes"])

      # Step 5: Verify the appointment was created by checking the database
      created_appointment = Appointment.last
      expect(created_appointment.provider_id).to eq(provider.id)
      expect(created_appointment.client_id).to eq(client.id)
      expect(created_appointment.status).to eq("scheduled")
    end
  end

  describe "booking conflicting appointments" do
    let(:provider) { create(:provider, :dr_wilson) }
    let(:client1) { create(:client, :jane_smith) }
    let(:client2) { create(:client, :bob_johnson) }

    before do
      create(:availability, :full_day_slot, provider: provider)
    end

    it "prevents conflicting appointment bookings" do
      # Step 1: Book first appointment
      appointment_time_start = 4.days.from_now.beginning_of_day + 10.hours
      appointment_time_end = 4.days.from_now.beginning_of_day + 11.hours

      appointment_params = {
        client_id: client1.id,
        provider_id: provider.id,
        starts_at: appointment_time_start.iso8601,
        ends_at: appointment_time_end.iso8601,
        duration_minutes: 60
      }

      post appointments_path, params: appointment_params
      expect(response).to have_http_status(:created)

      # Step 2: Try to book conflicting appointment
      conflicting_params = {
        client_id: client2.id,
        provider_id: provider.id,
        starts_at: appointment_time_start.iso8601,
        ends_at: appointment_time_end.iso8601,
        duration_minutes: 60
      }

      expect {
        post appointments_path, params: conflicting_params
      }.not_to change { Appointment.count }

      expect(response).to have_http_status(:bad_request)
      error_response = JSON.parse(response.body)
      expect(error_response["error"]).to include("conflicts with existing appointments")
    end
  end

  describe "booking and cancelling appointments" do
    let(:provider) { create(:provider, :dr_wilson) }
    let(:client) { create(:client, :jane_smith) }
    let(:client2) { create(:client, :bob_johnson) }

    before do
      create(:availability, :full_day_slot, provider: provider)
    end

    it "allows rebooking after cancellation" do
      # Step 1: Book an appointment
      appointment_time_start = 4.days.from_now.beginning_of_day + 12.hours
      appointment_time_end = 4.days.from_now.beginning_of_day + 13.hours

      appointment_params = {
        client_id: client.id,
        provider_id: provider.id,
        starts_at: appointment_time_start.iso8601,
        ends_at: appointment_time_end.iso8601,
        duration_minutes: 60
      }

      post appointments_path, params: appointment_params
      expect(response).to have_http_status(:created)
      appointment_response = JSON.parse(response.body)
      appointment_id = appointment_response["id"]

      # Step 2: Cancel the appointment
      delete appointment_path(appointment_id)
      expect(response).to have_http_status(:success)

      cancel_response = JSON.parse(response.body)
      expect(cancel_response["status"]).to eq("cancelled")

      # Step 3: Verify another client can now book the same slot
      new_appointment_params = {
        client_id: client2.id,
        provider_id: provider.id,
        starts_at: appointment_time_start.iso8601,
        ends_at: appointment_time_end.iso8601,
        duration_minutes: 60
      }

      expect {
        post appointments_path, params: new_appointment_params
      }.to change { Appointment.count }.by(1)

      expect(response).to have_http_status(:created)
    end
  end

  describe "booking with different providers" do
    let(:provider1) { create(:provider, :dr_smith) }
    let(:provider2) { create(:provider, :dr_jones) }
    let(:client1) { create(:client, :jane_smith) }
    let(:client2) { create(:client, :bob_johnson) }

    before do
      create(:availability, :morning_slot, provider: provider1)
      create(:availability, provider: provider2,
        starts_at: 3.days.from_now.beginning_of_day + 10.hours,
        ends_at: 3.days.from_now.beginning_of_day + 16.hours
      )
    end

    it "allows simultaneous bookings with different providers" do
      # Step 1: Book appointment with first provider
      appointment_time_start1 = 2.days.from_now.beginning_of_day + 10.hours
      appointment_time_end1 = 2.days.from_now.beginning_of_day + 11.hours

      appointment1_params = {
        client_id: client1.id,
        provider_id: provider1.id,
        starts_at: appointment_time_start1.iso8601,
        ends_at: appointment_time_end1.iso8601,
        duration_minutes: 60
      }

      post appointments_path, params: appointment1_params
      expect(response).to have_http_status(:created)

      # Step 2: Book same time slot with different provider
      appointment_time_start2 = 3.days.from_now.beginning_of_day + 10.hours
      appointment_time_end2 = 3.days.from_now.beginning_of_day + 11.hours

      appointment2_params = {
        client_id: client2.id,
        provider_id: provider2.id,
        starts_at: appointment_time_start2.iso8601,
        ends_at: appointment_time_end2.iso8601,
        duration_minutes: 60
      }

      expect {
        post appointments_path, params: appointment2_params
      }.to change { Appointment.count }.by(1)

      expect(response).to have_http_status(:created)
    end
  end

  describe "availability with gaps between appointments" do
    let(:provider) { create(:provider, :dr_wilson) }
    let(:client1) { create(:client, :jane_smith) }
    let(:client2) { create(:client, :bob_johnson) }
    let(:client3) { create(:client, :john_doe) }

    before do
      create(:availability, :full_day_slot, provider: provider)
    end

    it "shows correct free slots between appointments" do
      # Step 1: Book two appointments with gap in between
      # First appointment: 10-11 AM
      first_appointment_params = {
        client_id: client1.id,
        provider_id: provider.id,
        starts_at: (4.days.from_now.beginning_of_day + 10.hours).iso8601,
        ends_at: (4.days.from_now.beginning_of_day + 11.hours).iso8601,
        duration_minutes: 60
      }

      post appointments_path, params: first_appointment_params
      expect(response).to have_http_status(:created)

      # Second appointment: 2-3 PM (leaving 11 AM - 2 PM free)
      second_appointment_params = {
        client_id: client2.id,
        provider_id: provider.id,
        starts_at: (4.days.from_now.beginning_of_day + 14.hours).iso8601,
        ends_at: (4.days.from_now.beginning_of_day + 15.hours).iso8601,
        duration_minutes: 60
      }

      post appointments_path, params: second_appointment_params
      expect(response).to have_http_status(:created)

      # Step 2: Check availability - should show gaps
      from_time = 4.days.from_now.beginning_of_day + 8.hours
      to_time = 4.days.from_now.beginning_of_day + 18.hours

      get provider_availabilities_path(provider), params: {
        from: from_time.iso8601,
        to: to_time.iso8601
      }

      expect(response).to have_http_status(:success)
      availability_response = JSON.parse(response.body)
      availability = availability_response["availabilities"].first

      # Should show multiple available slots with gaps between appointments
      available_slots = availability["available_slots"]
      expect(available_slots.count).to be > 1

      # Should show 2 appointments
      expect(availability["total_appointments"]).to eq(2)

      # Step 3: Book an appointment in the gap
      gap_appointment_params = {
        client_id: client3.id,
        provider_id: provider.id,
        starts_at: (4.days.from_now.beginning_of_day + 12.hours).iso8601,
        ends_at: (4.days.from_now.beginning_of_day + 13.hours).iso8601,
        duration_minutes: 60
      }

      expect {
        post appointments_path, params: gap_appointment_params
      }.to change { Appointment.count }.by(1)

      expect(response).to have_http_status(:created)
    end
  end

  describe "error handling throughout the booking flow" do
    it "handles various error scenarios gracefully" do
      # Test 1: Invalid provider ID
      get provider_availabilities_path(999999), params: {
        from: 1.day.from_now.iso8601,
        to: 2.days.from_now.iso8601
      }

      expect(response).to have_http_status(:not_found)

      # Test 2: Missing date parameters
      provider = create(:provider)
      get provider_availabilities_path(provider), params: {}
      expect(response).to have_http_status(:bad_request)

      # Test 3: Invalid appointment parameters
      post appointments_path, params: {
        client_id: 999999,
        provider_id: provider.id,
        starts_at: 1.hour.from_now.iso8601,
        ends_at: 2.hours.from_now.iso8601
      }

      expect(response).to have_http_status(:not_found)

      # Test 4: Cancel non-existent appointment
      delete appointment_path(999999)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "booking outside availability window" do
    let(:provider) { create(:provider, :dr_smith) }
    let(:client) { create(:client, :jane_smith) }

    before do
      create(:availability, :morning_slot, provider: provider)
    end

    it "prevents booking outside availability window" do
      # Try to book way outside any availability window
      far_future_start = 30.days.from_now.beginning_of_day + 10.hours
      far_future_end = 30.days.from_now.beginning_of_day + 11.hours

      appointment_params = {
        client_id: client.id,
        provider_id: provider.id,
        starts_at: far_future_start.iso8601,
        ends_at: far_future_end.iso8601,
        duration_minutes: 60
      }

      expect {
        post appointments_path, params: appointment_params
      }.not_to change { Appointment.count }

      expect(response).to have_http_status(:bad_request)
      error_response = JSON.parse(response.body)
      expect(error_response["error"]).to include("No availability window found")
    end
  end

  describe "concurrent booking attempts" do
    let(:provider) { create(:provider, :dr_wilson) }
    let(:client1) { create(:client, :jane_smith) }
    let(:client2) { create(:client, :bob_johnson) }

    before do
      create(:availability, :full_day_slot, provider: provider)
    end

    it "handles concurrent booking attempts correctly" do
      # This test simulates multiple clients trying to book the same slot
      appointment_time_start = 4.days.from_now.beginning_of_day + 16.hours
      appointment_time_end = 4.days.from_now.beginning_of_day + 17.hours

      # Both clients try to book the same slot
      appointment_params1 = {
        client_id: client1.id,
        provider_id: provider.id,
        starts_at: appointment_time_start.iso8601,
        ends_at: appointment_time_end.iso8601,
        duration_minutes: 60
      }

      appointment_params2 = {
        client_id: client2.id,
        provider_id: provider.id,
        starts_at: appointment_time_start.iso8601,
        ends_at: appointment_time_end.iso8601,
        duration_minutes: 60
      }

      # First booking should succeed
      post appointments_path, params: appointment_params1
      expect(response).to have_http_status(:created)

      # Second booking should fail
      expect {
        post appointments_path, params: appointment_params2
      }.not_to change { Appointment.count }

      expect(response).to have_http_status(:bad_request)
      error_response = JSON.parse(response.body)
      expect(error_response["error"]).to include("conflicts with existing appointments")
    end
  end
end
