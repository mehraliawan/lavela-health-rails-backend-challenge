require 'rails_helper'

RSpec.describe Appointment, type: :model do
  describe 'validations' do
    it 'is valid with valid attributes' do
      appointment = build(:appointment)
      expect(appointment).to be_valid
    end

    it 'requires client' do
      appointment = build(:appointment, client: nil)
      expect(appointment).not_to be_valid
      expect(appointment.errors[:client]).to include("must exist")
    end

    it 'requires provider' do
      appointment = build(:appointment, provider: nil)
      expect(appointment).not_to be_valid
      expect(appointment.errors[:provider]).to include("must exist")
    end

    it 'requires availability' do
      appointment = build(:appointment, availability: nil)
      expect(appointment).not_to be_valid
      expect(appointment.errors[:availability]).to include("must exist")
    end

    it 'requires starts_at' do
      appointment = build(:appointment, starts_at: nil)
      expect(appointment).not_to be_valid
      expect(appointment.errors[:starts_at]).to include("can't be blank")
    end

    it 'requires ends_at' do
      appointment = build(:appointment, ends_at: nil)
      expect(appointment).not_to be_valid
      expect(appointment.errors[:ends_at]).to include("can't be blank")
    end

    it 'requires duration_minutes' do
      appointment = build(:appointment, duration_minutes: nil)
      expect(appointment).not_to be_valid
      expect(appointment.errors[:duration_minutes]).to include("can't be blank")
    end

    it 'requires status' do
      appointment = build(:appointment, status: nil)
      expect(appointment).not_to be_valid
      expect(appointment.errors[:status]).to include("can't be blank")
    end

    it 'validates duration_minutes is positive' do
      appointment = build(:appointment, duration_minutes: 0)
      expect(appointment).not_to be_valid
      expect(appointment.errors[:duration_minutes]).to include("must be greater than 0")
    end

    it 'validates status is valid' do
      appointment = build(:appointment, status: "invalid_status")
      expect(appointment).not_to be_valid
      expect(appointment.errors[:status]).to include("is not included in the list")
    end

    it 'validates ends_at is after starts_at' do
      start_time = 2.hours.from_now
      appointment = build(:appointment, starts_at: start_time, ends_at: start_time - 1.hour)
      expect(appointment).not_to be_valid
      expect(appointment.errors[:ends_at]).to include("must be after start time")
    end

    it 'validates duration matches time range' do
      start_time = 2.hours.from_now
      end_time = start_time + 1.hour
      appointment = build(:appointment,
        starts_at: start_time,
        ends_at: end_time,
        duration_minutes: 120  # 2 hours, but time range is 1 hour
      )
      expect(appointment).not_to be_valid
      expect(appointment.errors[:duration_minutes]).to include("must match the time range")
    end

    describe 'appointment within availability window' do
      it 'is valid when appointment is within availability window' do
        availability = create(:availability, :full_day_slot)
        appointment = build(:appointment,
          availability: availability,
          starts_at: availability.starts_at + 2.hours,
          ends_at: availability.starts_at + 3.hours,
          duration_minutes: 60
        )
        expect(appointment).to be_valid
      end

      it 'is invalid when appointment extends beyond availability window' do
        availability = create(:availability, :morning_slot)
        appointment = build(:appointment,
          client: create(:client),
          provider: availability.provider,
          availability: availability,
          starts_at: availability.ends_at - 30.minutes,
          ends_at: availability.ends_at + 30.minutes,
          duration_minutes: 60
        )
        expect(appointment).not_to be_valid
        expect(appointment.errors[:base]).to include("appointment must be within the availability window")
      end
    end

    describe 'no overlapping appointments' do
      let(:provider) { create(:provider) }
      let(:availability) { create(:availability, :full_day_slot, provider: provider) }

      it 'prevents overlapping appointments for same provider' do
        existing_appointment = create(:appointment,
          provider: provider,
          availability: availability,
          starts_at: availability.starts_at + 2.hours,
          ends_at: availability.starts_at + 3.hours
        )

        overlapping_appointment = build(:appointment,
          provider: provider,
          availability: availability,
          starts_at: existing_appointment.starts_at + 30.minutes,
          ends_at: existing_appointment.ends_at + 30.minutes,
          duration_minutes: 60
        )

        expect(overlapping_appointment).not_to be_valid
        expect(overlapping_appointment.errors[:base]).to include("appointment conflicts with existing appointments")
      end

      it 'allows appointments that do not overlap' do
        existing_appointment = create(:appointment,
          provider: provider,
          availability: availability,
          starts_at: availability.starts_at + 2.hours,
          ends_at: availability.starts_at + 3.hours
        )

        non_overlapping_appointment = build(:appointment,
          provider: provider,
          availability: availability,
          starts_at: existing_appointment.ends_at,
          ends_at: existing_appointment.ends_at + 1.hour,
          duration_minutes: 60
        )

        expect(non_overlapping_appointment).to be_valid
      end

      it 'ignores cancelled appointments when checking for overlaps' do
        cancelled_appointment = create(:appointment, :cancelled,
          provider: provider,
          availability: availability,
          starts_at: availability.starts_at + 2.hours,
          ends_at: availability.starts_at + 3.hours
        )

        new_appointment = build(:appointment,
          provider: provider,
          availability: availability,
          starts_at: cancelled_appointment.starts_at,
          ends_at: cancelled_appointment.ends_at,
          duration_minutes: 60
        )

        expect(new_appointment).to be_valid
      end
    end
  end

  describe 'associations' do
    it 'belongs to client' do
      association = described_class.reflect_on_association(:client)
      expect(association.macro).to eq(:belongs_to)
    end

    it 'belongs to provider' do
      association = described_class.reflect_on_association(:provider)
      expect(association.macro).to eq(:belongs_to)
    end

    it 'belongs to availability' do
      association = described_class.reflect_on_association(:availability)
      expect(association.macro).to eq(:belongs_to)
    end
  end

  describe 'scopes' do
    describe '.active' do
      it 'excludes cancelled appointments' do
        scheduled = create(:appointment, :scheduled)
        confirmed = create(:appointment, :confirmed)
        cancelled = create(:appointment, :cancelled)

        active_appointments = Appointment.active
        expect(active_appointments).to include(scheduled, confirmed)
        expect(active_appointments).not_to include(cancelled)
      end
    end

    describe '.for_provider' do
      it 'filters by provider' do
        provider1 = create(:provider)
        provider2 = create(:provider)
        availability1 = create(:availability, provider: provider1)
        availability2 = create(:availability, provider: provider2)
        appointment1 = create(:appointment, provider: provider1, availability: availability1)
        appointment2 = create(:appointment, provider: provider2, availability: availability2)

        appointments = Appointment.for_provider(provider1.id)
        expect(appointments).to include(appointment1)
        expect(appointments).not_to include(appointment2)
      end
    end

    describe '.between' do
      it 'finds appointments in time range' do
        appointment = create(:appointment, :tomorrow_morning)
        start_time = appointment.starts_at - 1.hour
        end_time = appointment.ends_at + 1.hour

        appointments = Appointment.between(start_time, end_time)
        expect(appointments).to include(appointment)
      end

      it 'excludes appointments outside time range' do
        appointment = create(:appointment, :tomorrow_morning)
        start_time = appointment.ends_at + 1.hour
        end_time = appointment.ends_at + 2.hours

        appointments = Appointment.between(start_time, end_time)
        expect(appointments).not_to include(appointment)
      end
    end
  end

  describe 'instance methods' do
    describe '#cancel!' do
      it 'changes status to cancelled' do
        appointment = create(:appointment, :scheduled)
        expect(appointment.status).to eq("scheduled")

        appointment.cancel!
        expect(appointment.status).to eq("cancelled")
      end
    end

    describe '#cancelled?' do
      it 'returns true for cancelled appointments' do
        appointment = create(:appointment, :cancelled)
        expect(appointment.cancelled?).to be true
      end

      it 'returns false for non-cancelled appointments' do
        appointment = create(:appointment, :scheduled)
        expect(appointment.cancelled?).to be false
      end
    end
  end

  describe 'factory traits' do
    it 'creates scheduled appointment' do
      appointment = create(:appointment, :scheduled)
      expect(appointment.status).to eq("scheduled")
    end

    it 'creates confirmed appointment' do
      appointment = create(:appointment, :confirmed)
      expect(appointment.status).to eq("confirmed")
    end

    it 'creates cancelled appointment' do
      appointment = create(:appointment, :cancelled)
      expect(appointment.status).to eq("cancelled")
    end

    it 'creates one_hour appointment with correct duration' do
      appointment = create(:appointment, :one_hour)
      expect(appointment.duration_minutes).to eq(60)
      expect((appointment.ends_at - appointment.starts_at) / 1.minute).to eq(60)
    end

    it 'creates thirty_minutes appointment with correct duration' do
      appointment = create(:appointment, :thirty_minutes)
      expect(appointment.duration_minutes).to eq(30)
      expect((appointment.ends_at - appointment.starts_at) / 1.minute).to eq(30)
    end
  end
end
