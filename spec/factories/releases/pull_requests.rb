FactoryBot.define do
  factory :releases_pull_request, class: 'Releases::PullRequest' do
    number { "" }
    source_id { "MyString" }
    url { "MyString" }
    title { "MyString" }
    body { "MyString" }
    state { "MyString" }
  end
end
