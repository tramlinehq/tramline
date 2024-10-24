FactoryBot.define do
  factory :approval_assignee do
    approval_item
    assignee { approval_item.author }
  end
end
