require 'rails_helper'

RSpec.describe "Appointments", type: :request do
  describe "POST /appointments" do
    let(:client) { create(:client, :jane_smith) }
    let(:provider) { create(:provider, :dr_wilson) }
    let(:availability) { create(:availability, :full_day_slot, provider: provider) }

    context "with valid data" do
      let(:valid_params) do
        {
          client_id: client.id,
          provider_id: provider.id,
          starts_at: (4.days.from_now.beginning_of_day + 15.hours).iso8601,
          ends_at: (4.days.from_now.beginning_of_day + 16.hours).iso8601,
          duration_minutes: 60
        }
      end

      it "creates an appointment" do
        availability # ensure availability is created
        expect {
          post appointments_path, params: valid_params
        }.to change { Appointment.count }.by(1)

        expect(response).to have_http_status(:created)

        response_data = JSON.parse(response.body)
        expect(response_data["client_id"]).to eq(client.id)
        expect(response_data["provider_id"]).to eq(provider.id)
        expect(response_data["status"]).to eq("scheduled")
        expect(response_data["duration_minutes"]).to eq(60)
      end

      it "calculates duration when not provided" do
        availability # ensure availability is created
        params_without_duration = valid_params.except(:duration_minutes)
        params_without_duration[:ends_at] = (4.days.from_now.beginning_of_day + 16.5.hours).iso8601

        post appointments_path, params: params_without_duration

        expect(response).to have_http_status(:created)

        response_data = JSON.parse(response.body)
        expect(response_data["duration_minutes"]).to eq(90) # 1.5 hours = 90 minutes
      end

      it "uses provided duration when given" do
        availability # ensure availability is created
        post appointments_path, params: valid_params

        expect(response).to have_http_status(:created)

        response_data = JSON.parse(response.body)
        expect(response_data["duration_minutes"]).to eq(60)
      end
    end

    context "with missing required params" do
      it "returns error with missing client_id" do
        params = { provider_id: provider.id }

        post appointments_path, params: params

        expect(response).to have_http_status(:bad_request)
        response_data = JSON.parse(response.body)
        expect(response_data["error"]).to include("Missing required parameters")
      end

      it "returns error with missing provider_id" do
        params = { client_id: client.id }

        post appointments_path, params: params

        expect(response).to have_http_status(:bad_request)
        response_data = JSON.parse(response.body)
        expect(response_data["error"]).to include("Missing required parameters")
      end

      it "returns error with missing starts_at" do
        params = { client_id: client.id, provider_id: provider.id, ends_at: 2.hours.from_now.iso8601 }

        post appointments_path, params: params

        expect(response).to have_http_status(:bad_request)
        response_data = JSON.parse(response.body)
        expect(response_data["error"]).to include("Missing required parameters")
      end

      it "returns error with missing ends_at" do
        params = { client_id: client.id, provider_id: provider.id, starts_at: 2.hours.from_now.iso8601 }

        post appointments_path, params: params

        expect(response).to have_http_status(:bad_request)
        response_data = JSON.parse(response.body)
        expect(response_data["error"]).to include("Missing required parameters")
      end
    end

    context "with invalid IDs" do
      it "returns error with invalid client_id" do
        params = {
          client_id: 999999,
          provider_id: provider.id,
          starts_at: 2.hours.from_now.iso8601,
          ends_at: 3.hours.from_now.iso8601
        }

        post appointments_path, params: params

        expect(response).to have_http_status(:not_found)
        response_data = JSON.parse(response.body)
        expect(response_data["error"]).to include("Couldn't find Client")
      end

      it "returns error with invalid provider_id" do
        params = {
          client_id: client.id,
          provider_id: 999999,
          starts_at: 2.hours.from_now.iso8601,
          ends_at: 3.hours.from_now.iso8601
        }

        post appointments_path, params: params

        expect(response).to have_http_status(:not_found)
        response_data = JSON.parse(response.body)
        expect(response_data["error"]).to include("Couldn't find Provider")
      end
    end

    context "with invalid datetime formats" do
      it "returns error with invalid datetime format" do
        params = {
          client_id: client.id,
          provider_id: provider.id,
          starts_at: "invalid-datetime",
          ends_at: "invalid-datetime"
        }

        post appointments_path, params: params

        expect(response).to have_http_status(:bad_request)
        response_data = JSON.parse(response.body)
        expect(response_data["error"]).to include("Invalid datetime format")
      end

      it "returns error when start time is after end time" do
        params = {
          client_id: client.id,
          provider_id: provider.id,
          starts_at: 3.hours.from_now.iso8601,
          ends_at: 2.hours.from_now.iso8601
        }

        post appointments_path, params: params

        expect(response).to have_http_status(:bad_request)
        response_data = JSON.parse(response.body)
        expect(response_data["error"]).to include("Start time must be before end time")
      end

      it "returns error when booking in the past" do
        params = {
          client_id: client.id,
          provider_id: provider.id,
          starts_at: 2.hours.ago.iso8601,
          ends_at: 1.hour.ago.iso8601
        }

        post appointments_path, params: params

        expect(response).to have_http_status(:bad_request)
        response_data = JSON.parse(response.body)
        expect(response_data["error"]).to include("Cannot book appointments in the past")
      end
    end

    context "with availability conflicts" do
      it "returns error when no availability window found" do
        params = {
          client_id: client.id,
          provider_id: provider.id,
          starts_at: 10.days.from_now.iso8601,
          ends_at: (10.days.from_now + 1.hour).iso8601
        }

        post appointments_path, params: params

        expect(response).to have_http_status(:bad_request)
        response_data = JSON.parse(response.body)
        expect(response_data["error"]).to include("No availability window found")
      end

      it "returns error when time slot conflicts with existing appointment" do
        existing_appointment = create(:appointment,
          provider: provider,
          availability: availability,
          starts_at: availability.starts_at + 2.hours,
          ends_at: availability.starts_at + 3.hours
        )

        params = {
          client_id: client.id,
          provider_id: existing_appointment.provider_id,
          starts_at: existing_appointment.starts_at.iso8601,
          ends_at: existing_appointment.ends_at.iso8601
        }

        post appointments_path, params: params

        expect(response).to have_http_status(:bad_request)
        response_data = JSON.parse(response.body)
        expect(response_data["error"]).to include("conflicts with existing appointments")
      end
    end
  end

  describe "DELETE /appointments/:id" do
    let(:appointment) { create(:appointment, :scheduled) }

    context "with valid appointment" do
      it "cancels an appointment" do
        expect(appointment.status).to eq("scheduled")

        delete appointment_path(appointment)

        expect(response).to have_http_status(:success)

        response_data = JSON.parse(response.body)
        expect(response_data["id"]).to eq(appointment.id)
        expect(response_data["status"]).to eq("cancelled")
        expect(response_data["message"]).to include("successfully cancelled")

        appointment.reload
        expect(appointment.status).to eq("cancelled")
      end

      it "works for already cancelled appointment" do
        cancelled_appointment = create(:appointment, :cancelled)
        expect(cancelled_appointment.status).to eq("cancelled")

        delete appointment_path(cancelled_appointment)

        expect(response).to have_http_status(:success)

        response_data = JSON.parse(response.body)
        expect(response_data["status"]).to eq("cancelled")
      end
    end

    context "with invalid appointment ID" do
      it "returns error for non-existent appointment" do
        delete appointment_path(999999)

        expect(response).to have_http_status(:not_found)
        response_data = JSON.parse(response.body)
        expect(response_data["error"]).to include("Appointment not found")
      end
    end
  end
end
