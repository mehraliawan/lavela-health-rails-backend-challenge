require 'rails_helper'

RSpec.describe Provider, type: :model do
  describe 'validations' do
    it 'is valid with valid attributes' do
      provider = build(:provider)
      expect(provider).to be_valid
    end

    it 'requires name' do
      provider = build(:provider, name: nil)
      expect(provider).not_to be_valid
      expect(provider.errors[:name]).to include("can't be blank")
    end

    it 'requires email' do
      provider = build(:provider, email: nil)
      expect(provider).not_to be_valid
      expect(provider.errors[:email]).to include("can't be blank")
    end

    it 'requires unique email' do
      existing_provider = create(:provider, email: "test@example.com")
      provider = build(:provider, email: existing_provider.email)
      expect(provider).not_to be_valid
      expect(provider.errors[:email]).to include("has already been taken")
    end

    it 'requires valid email format' do
      provider = build(:provider, email: "invalid-email")
      expect(provider).not_to be_valid
      expect(provider.errors[:email]).to include("is invalid")
    end
  end

  describe 'associations' do
    it 'has many availabilities' do
      association = described_class.reflect_on_association(:availabilities)
      expect(association.macro).to eq(:has_many)
    end

    it 'has many appointments' do
      association = described_class.reflect_on_association(:appointments)
      expect(association.macro).to eq(:has_many)
    end

    it 'has availabilities' do
      provider = create(:provider, :with_availabilities)
      expect(provider.availabilities.count).to be > 0
    end

    it 'has appointments through availabilities' do
      provider = create(:provider)
      availability = create(:availability, provider: provider)
      appointment = create(:appointment, provider: provider, availability: availability)

      expect(provider.appointments).to include(appointment)
    end
  end

  describe 'dependent destroy' do
    it 'destroys dependent availabilities when deleted' do
      provider = create(:provider)
      create(:availability, provider: provider)

      expect { provider.destroy }.to change { Availability.count }.by(-1)
    end

    it 'destroys dependent appointments when deleted' do
      provider = create(:provider)
      availability = create(:availability, provider: provider)
      create(:appointment, provider: provider, availability: availability)

      expect { provider.destroy }.to change { Appointment.count }.by(-1)
    end
  end

  describe 'factory traits' do
    it 'creates dr_smith with correct attributes' do
      provider = create(:provider, :dr_smith)
      expect(provider.name).to eq("Dr. Sarah Smith")
      expect(provider.email).to eq("dr.smith@example.com")
    end

    it 'creates dr_jones with correct attributes' do
      provider = create(:provider, :dr_jones)
      expect(provider.name).to eq("Dr. Michael Jones")
      expect(provider.email).to eq("dr.jones@example.com")
    end

    it 'creates dr_wilson with correct attributes' do
      provider = create(:provider, :dr_wilson)
      expect(provider.name).to eq("Dr. Emily Wilson")
      expect(provider.email).to eq("dr.wilson@example.com")
    end
  end
end
