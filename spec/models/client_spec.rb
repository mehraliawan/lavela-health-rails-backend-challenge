require 'rails_helper'

RSpec.describe Client, type: :model do
  describe 'validations' do
    it 'is valid with valid attributes' do
      client = build(:client)
      expect(client).to be_valid
    end

    it 'requires name' do
      client = build(:client, name: nil)
      expect(client).not_to be_valid
      expect(client.errors[:name]).to include("can't be blank")
    end

    it 'requires email' do
      client = build(:client, email: nil)
      expect(client).not_to be_valid
      expect(client.errors[:email]).to include("can't be blank")
    end

    it 'requires unique email' do
      existing_client = create(:client, email: "test@example.com")
      client = build(:client, email: existing_client.email)
      expect(client).not_to be_valid
      expect(client.errors[:email]).to include("has already been taken")
    end

    it 'requires valid email format' do
      client = build(:client, email: "invalid-email")
      expect(client).not_to be_valid
      expect(client.errors[:email]).to include("is invalid")
    end

    describe 'phone validation' do
      it 'validates phone format when present' do
        client = build(:client, phone: "invalid-phone")
        expect(client).not_to be_valid
        expect(client.errors[:phone]).to include("must be a valid phone number")
      end

      it 'allows blank phone' do
        client = build(:client, phone: "")
        expect(client).to be_valid
      end

      it 'allows nil phone' do
        client = build(:client, phone: nil)
        expect(client).to be_valid
      end

      it 'allows valid phone formats' do
        valid_phones = [ "+1-555-0123", "+15550123", "555-0123" ]
        valid_phones.each do |phone|
          client = build(:client, phone: phone)
          expect(client).to be_valid, "#{phone} should be valid"
        end
      end
    end
  end

  describe 'associations' do
    it 'has many appointments' do
      association = described_class.reflect_on_association(:appointments)
      expect(association.macro).to eq(:has_many)
    end

    it 'has appointments' do
      client = create(:client)
      provider = create(:provider)
      availability = create(:availability, provider: provider)
      appointment = create(:appointment, client: client, provider: provider, availability: availability)

      expect(client.appointments).to include(appointment)
    end
  end

  describe 'dependent destroy' do
    it 'destroys dependent appointments when deleted' do
      client = create(:client)
      provider = create(:provider)
      availability = create(:availability, provider: provider)
      create(:appointment, client: client, provider: provider, availability: availability)

      expect { client.destroy }.to change { Appointment.count }.by(-1)
    end
  end

  describe 'factory traits' do
    it 'creates john_doe with correct attributes' do
      client = create(:client, :john_doe)
      expect(client.name).to eq("John Doe")
      expect(client.email).to eq("john.doe@example.com")
      expect(client.phone).to eq("+1-555-0123")
    end

    it 'creates jane_smith with correct attributes' do
      client = create(:client, :jane_smith)
      expect(client.name).to eq("Jane Smith")
      expect(client.email).to eq("jane.smith@example.com")
      expect(client.phone).to eq("+1-555-0456")
    end

    it 'creates bob_johnson with correct attributes' do
      client = create(:client, :bob_johnson)
      expect(client.name).to eq("Bob Johnson")
      expect(client.email).to eq("bob.johnson@example.com")
      expect(client.phone).to eq("+1-555-0789")
    end
  end
end
