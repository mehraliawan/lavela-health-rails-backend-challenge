require 'rails_helper'

RSpec.describe "Providers::Availabilities", type: :request do
  describe "GET /providers/:provider_id/availabilities" do
    let(:provider) { create(:provider, :dr_smith) }

    context "with valid parameters" do
      let(:from_time) { 1.day.from_now.beginning_of_day }
      let(:to_time) { 5.days.from_now.end_of_day }

      before do
        create(:availability, :morning_slot, provider: provider)
        create(:availability, :afternoon_slot, provider: provider)
      end

      it "returns availabilities with valid params" do
        get provider_availabilities_path(provider), params: {
          from: from_time.iso8601,
          to: to_time.iso8601
        }

        expect(response).to have_http_status(:success)

        response_data = JSON.parse(response.body)
        expect(response_data["provider_id"]).to eq(provider.id)
        expect(response_data["provider_name"]).to eq(provider.name)
        expect(response_data["from"]).to eq(from_time.iso8601)
        expect(response_data["to"]).to eq(to_time.iso8601)
        expect(response_data["availabilities"]).to be_an(Array)
      end

      it "includes availability details" do
        get provider_availabilities_path(provider), params: {
          from: from_time.iso8601,
          to: to_time.iso8601
        }

        expect(response).to have_http_status(:success)

        response_data = JSON.parse(response.body)
        availabilities = response_data["availabilities"]

        expect(availabilities.count).to be > 0

        availability = availabilities.first
        expect(availability).to have_key("id")
        expect(availability).to have_key("external_id")
        expect(availability).to have_key("starts_at")
        expect(availability).to have_key("ends_at")
        expect(availability).to have_key("source")
        expect(availability).to have_key("available_slots")
        expect(availability).to have_key("total_appointments")
      end

      it "shows free slots correctly for availability with no appointments" do
        afternoon_availability = create(:availability, :afternoon_slot, provider: provider)
        from_time = afternoon_availability.starts_at - 1.hour
        to_time = afternoon_availability.ends_at + 1.hour

        get provider_availabilities_path(provider), params: {
          from: from_time.iso8601,
          to: to_time.iso8601
        }

        expect(response).to have_http_status(:success)

        response_data = JSON.parse(response.body)
        availabilities = response_data["availabilities"]

        # Find our afternoon availability
        afternoon_data = availabilities.find { |a| a["id"] == afternoon_availability.id }
        expect(afternoon_data).not_to be_nil

        # Should have available slots since no appointments are booked
        expect(afternoon_data["available_slots"].count).to be > 0
        expect(afternoon_data["total_appointments"]).to eq(0)
      end

      it "handles booked slots correctly" do
        morning_availability = create(:availability, :morning_slot, provider: provider)
        create(:appointment,
          provider: provider,
          availability: morning_availability,
          starts_at: morning_availability.starts_at + 1.hour,
          ends_at: morning_availability.starts_at + 2.hours
        )

        from_time = morning_availability.starts_at - 1.hour
        to_time = morning_availability.ends_at + 1.hour

        get provider_availabilities_path(provider), params: {
          from: from_time.iso8601,
          to: to_time.iso8601
        }

        expect(response).to have_http_status(:success)

        response_data = JSON.parse(response.body)
        availabilities = response_data["availabilities"]

        # Find our morning availability
        morning_data = availabilities.find { |a| a["id"] == morning_availability.id }
        expect(morning_data).not_to be_nil

        # Should show appointments count
        expect(morning_data["total_appointments"]).to be > 0
      end

      it "calculates available slots with correct duration" do
        afternoon_availability = create(:availability, :afternoon_slot, provider: provider)
        from_time = afternoon_availability.starts_at - 1.hour
        to_time = afternoon_availability.ends_at + 1.hour

        get provider_availabilities_path(provider), params: {
          from: from_time.iso8601,
          to: to_time.iso8601
        }

        expect(response).to have_http_status(:success)

        response_data = JSON.parse(response.body)
        availabilities = response_data["availabilities"]

        afternoon_data = availabilities.find { |a| a["id"] == afternoon_availability.id }
        expect(afternoon_data).not_to be_nil

        available_slots = afternoon_data["available_slots"]
        expect(available_slots.count).to be > 0

        # Check that duration calculation is correct
        slot = available_slots.first
        starts_at = Time.parse(slot["starts_at"])
        ends_at = Time.parse(slot["ends_at"])
        expected_duration = ((ends_at - starts_at) / 1.minute).round

        expect(slot["duration_minutes"]).to eq(expected_duration)
      end

      it "filters by time range correctly" do
        # Use a narrow time range that should only include morning availability
        from_time = 2.days.from_now.beginning_of_day + 8.hours
        to_time = 2.days.from_now.beginning_of_day + 13.hours

        get provider_availabilities_path(provider), params: {
          from: from_time.iso8601,
          to: to_time.iso8601
        }

        expect(response).to have_http_status(:success)

        response_data = JSON.parse(response.body)
        availabilities = response_data["availabilities"]

        # Should only include availabilities that overlap with our time range
        availabilities.each do |availability|
          starts_at = Time.parse(availability["starts_at"])
          ends_at = Time.parse(availability["ends_at"])

          # Availability should overlap with our requested time range
          expect(starts_at).to be < to_time
          expect(ends_at).to be > from_time
        end
      end
    end

    context "with invalid provider" do
      it "returns error for non-existent provider" do
        from_time = 1.day.from_now.beginning_of_day
        to_time = 5.days.from_now.end_of_day

        get provider_availabilities_path(999999), params: {
          from: from_time.iso8601,
          to: to_time.iso8601
        }

        expect(response).to have_http_status(:not_found)
        response_data = JSON.parse(response.body)
        expect(response_data["error"]).to include("Provider not found")
      end
    end

    context "with missing parameters" do
      it "requires from parameter" do
        to_time = 5.days.from_now.end_of_day

        get provider_availabilities_path(provider), params: {
          to: to_time.iso8601
        }

        expect(response).to have_http_status(:bad_request)
        response_data = JSON.parse(response.body)
        expect(response_data["error"]).to include("Both from and to parameters are required")
      end

      it "requires to parameter" do
        from_time = 1.day.from_now.beginning_of_day

        get provider_availabilities_path(provider), params: {
          from: from_time.iso8601
        }

        expect(response).to have_http_status(:bad_request)
        response_data = JSON.parse(response.body)
        expect(response_data["error"]).to include("Both from and to parameters are required")
      end
    end

    context "with invalid date formats" do
      it "validates date format" do
        get provider_availabilities_path(provider), params: {
          from: "invalid-date",
          to: "invalid-date"
        }

        expect(response).to have_http_status(:bad_request)
        response_data = JSON.parse(response.body)
        expect(response_data["error"]).to include("Invalid date format")
      end

      it "validates from is before to" do
        from_time = 5.days.from_now.beginning_of_day
        to_time = 1.day.from_now.end_of_day

        get provider_availabilities_path(provider), params: {
          from: from_time.iso8601,
          to: to_time.iso8601
        }

        expect(response).to have_http_status(:bad_request)
        response_data = JSON.parse(response.body)
        expect(response_data["error"]).to include("From time must be before to time")
      end
    end

    context "with fully booked availability windows" do
      it "excludes fully booked availability windows" do
        availability = create(:availability, :morning_slot, provider: provider)

        # Create an appointment that fills the entire availability window
        create(:appointment,
          provider: provider,
          availability: availability,
          starts_at: availability.starts_at,
          ends_at: availability.ends_at,
          duration_minutes: ((availability.ends_at - availability.starts_at) / 1.minute).round,
          status: "scheduled"
        )

        from_time = availability.starts_at - 1.hour
        to_time = availability.ends_at + 1.hour

        get provider_availabilities_path(provider), params: {
          from: from_time.iso8601,
          to: to_time.iso8601
        }

        expect(response).to have_http_status(:success)

        response_data = JSON.parse(response.body)
        availabilities = response_data["availabilities"]

        # The fully booked availability should not be included
        fully_booked = availabilities.find { |a| a["id"] == availability.id }
        expect(fully_booked).to be_nil
      end
    end
  end
end
