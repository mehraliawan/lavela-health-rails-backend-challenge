FactoryBot.define do
  factory :client do
    sequence(:name) { |n| "Client #{n}" }
    sequence(:email) { |n| "client#{n}@example.com" }
    sequence(:phone) { |n| "+1-555-#{1000 + n}" }

    trait :john_doe do
      name { "John Doe" }
      email { "john.doe@example.com" }
      phone { "+1-555-0123" }
    end

    trait :jane_smith do
      name { "Jane Smith" }
      email { "jane.smith@example.com" }
      phone { "+1-555-0456" }
    end

    trait :bob_johnson do
      name { "Bob Johnson" }
      email { "bob.johnson@example.com" }
      phone { "+1-555-0789" }
    end
  end
end
