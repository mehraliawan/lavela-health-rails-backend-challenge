FactoryBot.define do
  factory :provider do
    sequence(:name) { |n| "Dr. Provider #{n}" }
    sequence(:email) { |n| "doctor#{n}@example.com" }

    trait :with_availabilities do
      after(:create) do |provider|
        create_list(:availability, 2, provider: provider)
      end
    end

    trait :dr_smith do
      name { "Dr. Sarah Smith" }
      email { "dr.smith@example.com" }
    end

    trait :dr_jones do
      name { "Dr. Michael Jones" }
      email { "dr.jones@example.com" }
    end

    trait :dr_wilson do
      name { "Dr. Emily Wilson" }
      email { "dr.wilson@example.com" }
    end
  end
end
