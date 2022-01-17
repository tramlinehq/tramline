class User < ApplicationRecord
  include ActiveModel::Validations
  devise :database_authenticatable, :registerable, :trackable, :lockable,
    :recoverable, :confirmable, :timeoutable, :rememberable, :validatable

  validates :password, password_strength: {use_dictionary: true}, allow_nil: true

  after_validation :strip_unnecessary_errors

  private

  # We only want to display one error message to the user, so if we get multiple
  # errors clear out all errors and present our nice message to the user.
  def strip_unnecessary_errors
    if errors[:password].any? && errors[:password].size > 1
      errors.delete(:password)
      errors.add(:password, I18n.translate("errors.messages.password.password_strength"))
    end
  end
end
