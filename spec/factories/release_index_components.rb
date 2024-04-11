FactoryBot.define do
  factory :release_index_component do
    name { ReleaseIndex::COMPONENTS.keys.sample }
    release_index { association :release_index }
    tolerable_range { 1..10 }
    weight { 0.5 }
  end
end
