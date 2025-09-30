require 'rails_helper'

RSpec.describe Availability, type: :model do
  describe 'validations' do
    it 'is valid with valid attributes' do
      availability = build(:availability)
      expect(availability).to be_valid
    end

    it 'requires provider' do
      availability = build(:availability, provider: nil)
      expect(availability).not_to be_valid
      expect(availability.errors[:provider]).to include("must exist")
    end

    it 'requires external_id' do
      availability = build(:availability, external_id: nil)
      expect(availability).not_to be_valid
      expect(availability.errors[:external_id]).to include("can't be blank")
    end

    it 'requires unique external_id' do
      existing_availability = create(:availability, external_id: "unique_id")
      availability = build(:availability, external_id: existing_availability.external_id)
      expect(availability).not_to be_valid
      expect(availability.errors[:external_id]).to include("has already been taken")
    end

    it 'requires starts_at' do
      availability = build(:availability, starts_at: nil)
      expect(availability).not_to be_valid
      expect(availability.errors[:starts_at]).to include("can't be blank")
    end

    it 'requires ends_at' do
      availability = build(:availability, ends_at: nil)
      expect(availability).not_to be_valid
      expect(availability.errors[:ends_at]).to include("can't be blank")
    end

    it 'requires source' do
      availability = build(:availability, source: nil)
      expect(availability).not_to be_valid
      expect(availability.errors[:source]).to include("can't be blank")
    end

    it 'validates ends_at is after starts_at' do
      start_time = 2.hours.from_now
      availability = build(:availability, starts_at: start_time, ends_at: start_time - 1.hour)
      expect(availability).not_to be_valid
      expect(availability.errors[:ends_at]).to include("must be after start time")
    end
  end

  describe 'associations' do
    it 'belongs to provider' do
      association = described_class.reflect_on_association(:provider)
      expect(association.macro).to eq(:belongs_to)
    end

    it 'has many appointments' do
      association = described_class.reflect_on_association(:appointments)
      expect(association.macro).to eq(:has_many)
    end

    it 'destroys dependent appointments when deleted' do
      availability = create(:availability)
      create(:appointment, availability: availability)

      expect { availability.destroy }.to change { Appointment.count }.by(-1)
    end
  end

  describe 'scopes' do
    describe '.available_between' do
      let(:provider) { create(:provider) }

      before do
        # Create availabilities at different times
        @early_availability = create(:availability,
          provider: provider,
          starts_at: 1.day.from_now.beginning_of_day + 8.hours,
          ends_at: 1.day.from_now.beginning_of_day + 12.hours
        )

        @middle_availability = create(:availability,
          provider: provider,
          starts_at: 2.days.from_now.beginning_of_day + 10.hours,
          ends_at: 2.days.from_now.beginning_of_day + 14.hours
        )

        @late_availability = create(:availability,
          provider: provider,
          starts_at: 5.days.from_now.beginning_of_day + 9.hours,
          ends_at: 5.days.from_now.beginning_of_day + 17.hours
        )
      end

      it 'finds availabilities in time range' do
        start_time = 1.day.from_now.beginning_of_day
        end_time = 3.days.from_now.end_of_day

        availabilities = Availability.available_between(start_time, end_time)
        expect(availabilities).to include(@early_availability, @middle_availability)
        expect(availabilities).not_to include(@late_availability)
      end
    end

    describe '.for_provider' do
      it 'filters by provider' do
        provider1 = create(:provider)
        provider2 = create(:provider)
        availability1 = create(:availability, provider: provider1)
        availability2 = create(:availability, provider: provider2)

        availabilities = Availability.for_provider(provider1.id)
        expect(availabilities).to include(availability1)
        expect(availabilities).not_to include(availability2)
      end
    end
  end

  describe 'instance methods' do
    describe '#contains_time_range?' do
      let(:availability) { create(:availability, :morning_slot) }

      it 'returns true when time range is within availability' do
        start_time = availability.starts_at + 1.hour
        end_time = availability.starts_at + 2.hours

        expect(availability.contains_time_range?(start_time, end_time)).to be true
      end

      it 'returns false when time range extends beyond availability' do
        start_time = availability.starts_at + 1.hour
        end_time = availability.ends_at + 1.hour

        expect(availability.contains_time_range?(start_time, end_time)).to be false
      end

      it 'returns false when time range starts before availability' do
        start_time = availability.starts_at - 1.hour
        end_time = availability.starts_at + 1.hour

        expect(availability.contains_time_range?(start_time, end_time)).to be false
      end
    end

    describe '#available_for_appointment?' do
      let(:availability) { create(:availability, :full_day_slot) }

      context 'when no conflicting appointments' do
        it 'returns true' do
          start_time = availability.starts_at + 2.hours
          end_time = availability.starts_at + 3.hours

          expect(availability.available_for_appointment?(start_time, end_time)).to be true
        end
      end

      context 'when appointment conflicts exist' do
        before do
          create(:appointment,
            availability: availability,
            starts_at: availability.starts_at + 2.hours,
            ends_at: availability.starts_at + 3.hours,
            status: "scheduled"
          )
        end

        it 'returns false for overlapping time' do
          start_time = availability.starts_at + 2.hours
          end_time = availability.starts_at + 3.hours

          expect(availability.available_for_appointment?(start_time, end_time)).to be false
        end

        it 'returns true for non-overlapping time' do
          start_time = availability.starts_at + 4.hours
          end_time = availability.starts_at + 5.hours

          expect(availability.available_for_appointment?(start_time, end_time)).to be true
        end
      end

      context 'when cancelled appointments exist' do
        before do
          create(:appointment, :cancelled,
            availability: availability,
            starts_at: availability.starts_at + 2.hours,
            ends_at: availability.starts_at + 3.hours
          )
        end

        it 'ignores cancelled appointments' do
          start_time = availability.starts_at + 2.hours
          end_time = availability.starts_at + 3.hours

          expect(availability.available_for_appointment?(start_time, end_time)).to be true
        end
      end

      it 'returns false when time range is outside availability window' do
        start_time = availability.ends_at + 1.hour
        end_time = availability.ends_at + 2.hours

        expect(availability.available_for_appointment?(start_time, end_time)).to be false
      end
    end
  end

  describe 'factory traits' do
    it 'creates morning_slot with correct times' do
      availability = create(:availability, :morning_slot)
      expected_start = 2.days.from_now.beginning_of_day + 9.hours
      expected_end = 2.days.from_now.beginning_of_day + 12.hours

      expect(availability.starts_at.to_i).to eq(expected_start.to_i)
      expect(availability.ends_at.to_i).to eq(expected_end.to_i)
    end

    it 'creates afternoon_slot with correct times' do
      availability = create(:availability, :afternoon_slot)
      expected_start = 2.days.from_now.beginning_of_day + 14.hours
      expected_end = 2.days.from_now.beginning_of_day + 17.hours

      expect(availability.starts_at.to_i).to eq(expected_start.to_i)
      expect(availability.ends_at.to_i).to eq(expected_end.to_i)
    end

    it 'creates full_day_slot with correct times' do
      availability = create(:availability, :full_day_slot)
      expected_start = 4.days.from_now.beginning_of_day + 8.hours
      expected_end = 4.days.from_now.beginning_of_day + 18.hours

      expect(availability.starts_at.to_i).to eq(expected_start.to_i)
      expect(availability.ends_at.to_i).to eq(expected_end.to_i)
    end
  end
end
