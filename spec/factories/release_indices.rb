FactoryBot.define do
  factory :release_index do
    train
    tolerable_range { 0.1..0.2 }
  end
end
