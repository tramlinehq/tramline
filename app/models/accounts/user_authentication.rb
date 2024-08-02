# == Schema Information
#
# Table name: user_authentications
#
#  id                   :uuid             not null, primary key
#  authenticatable_type :string           not null, indexed => [authenticatable_id]
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  authenticatable_id   :uuid             not null, indexed => [authenticatable_type]
#  user_id              :uuid             indexed
#
class Accounts::UserAuthentication < ApplicationRecord
  belongs_to :user
  belongs_to :authenticatable, polymorphic: true

  validates :authenticatable_id, uniqueness: {scope: [:user_id, :authenticatable_type]}
end
