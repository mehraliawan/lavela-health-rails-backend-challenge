FactoryBot.define do
  factory :availability do
    association :provider
    sequence(:external_id) { |n| "availability_#{n}_#{SecureRandom.hex(4)}" }
    starts_at { 2.days.from_now.beginning_of_day + 9.hours }
    ends_at { 2.days.from_now.beginning_of_day + 17.hours }
    source { "calendly" }

    trait :morning_slot do
      starts_at { 2.days.from_now.beginning_of_day + 9.hours }
      ends_at { 2.days.from_now.beginning_of_day + 12.hours }
    end

    trait :afternoon_slot do
      starts_at { 2.days.from_now.beginning_of_day + 14.hours }
      ends_at { 2.days.from_now.beginning_of_day + 17.hours }
    end

    trait :full_day_slot do
      starts_at { 4.days.from_now.beginning_of_day + 8.hours }
      ends_at { 4.days.from_now.beginning_of_day + 18.hours }
    end

    trait :tomorrow do
      starts_at { 1.day.from_now.beginning_of_day + 10.hours }
      ends_at { 1.day.from_now.beginning_of_day + 16.hours }
    end
  end
end
