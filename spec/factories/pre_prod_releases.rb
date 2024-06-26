FactoryBot.define do
  factory :pre_prod_release do
    release_platform_run { association :release_platform_run }
    build { association :build }
    type { "InternalRelease" }
  end
end
