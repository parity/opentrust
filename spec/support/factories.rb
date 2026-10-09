FactoryBot.define do
  factory :merchant do
    sequence(:name) { |n| "Owner #{n}" }
    sequence(:business_name) { |n| "Shop#{n}" }
    sequence(:contact_email) { |n| "shop#{n}@example.com" }
    sequence(:phone) { |n| "98765#{format("%05d", n)}" }
    status { "approved" }
    checks_remaining { 100 }
  end
end

RSpec.configure { |c| c.include FactoryBot::Syntax::Methods }
