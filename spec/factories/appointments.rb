FactoryBot.define do
  factory :appointment do
    association :client
    association :provider
    association :availability
    starts_at { 2.days.from_now.beginning_of_day + 10.hours }
    ends_at { 2.days.from_now.beginning_of_day + 11.hours }
    duration_minutes { 60 }
    status { "scheduled" }

    trait :scheduled do
      status { "scheduled" }
    end

    trait :confirmed do
      status { "confirmed" }
    end

    trait :cancelled do
      status { "cancelled" }
    end

    trait :one_hour do
      duration_minutes { 60 }
      ends_at { starts_at + 1.hour }
    end

    trait :thirty_minutes do
      duration_minutes { 30 }
      ends_at { starts_at + 30.minutes }
    end

    trait :tomorrow_morning do
      starts_at { 1.day.from_now.beginning_of_day + 10.hours }
      ends_at { 1.day.from_now.beginning_of_day + 11.hours }

      # Create a matching availability for tomorrow morning
      after(:build) do |appointment|
        if appointment.availability.nil?
          appointment.availability = create(:availability, :tomorrow,
            provider: appointment.provider,
            starts_at: appointment.starts_at - 1.hour,
            ends_at: appointment.starts_at + 6.hours
          )
        end
      end
    end

    # Note: Appointments should be created within existing availability windows
    # Use specific availability factories or create custom availabilities for tests
  end
end
