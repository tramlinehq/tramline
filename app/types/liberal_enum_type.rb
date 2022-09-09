class LiberalEnumType < ActiveRecord::Enum::EnumType
  # suppress ArgumentError
  # returns a value to be able to use +inclusion+ validation
  def assert_valid_value(value)
    value
  end
end
