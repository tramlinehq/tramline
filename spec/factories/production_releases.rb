FactoryBot.define do
  factory :production_release do
    release_platform_run { association :release_platform_run }
    build { association :build }
    status { "inflight" }
  end
end
