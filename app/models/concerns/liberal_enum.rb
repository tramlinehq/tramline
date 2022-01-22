module LiberalEnum
  extend ActiveSupport::Concern

  class_methods do
    def liberal_enum(attribute)
      decorate_attribute_type(attribute, :enum) do |subtype|
        LiberalEnumType.new(attribute, public_send(attribute.to_s.pluralize), subtype)
      end
    end
  end
end
