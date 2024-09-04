FactoryBot.define do
  factory :pull_request do
    release
    number { "1" }
    source_id { "MyString" }
    url { "MyString" }
    title { "MyString" }
    body { "MyString" }
    state { "MyString" }
  end
end
