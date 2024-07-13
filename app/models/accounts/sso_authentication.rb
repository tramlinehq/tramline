# == Schema Information
#
# Table name: sso_authentications
#
#  id               :uuid             not null, primary key
#  email            :string           default(""), not null, indexed
#  logout_time      :datetime
#  sso_created_time :datetime
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  login_id         :string           not null, indexed
#
class Accounts::SsoAuthentication < ApplicationRecord
  has_one :user_authentication, as: :authenticatable, dependent: :destroy
  has_one :user, through: :user_authentication
end
