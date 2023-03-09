class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class
  self.implicit_order_column = :created_at

  # - column used is always `status`
  # - row-lock is always taken before update
  # - plays well with rails scopes and enums
  def self.safe_state_machine_params
    {
      column: :status,
      requires_lock: true,
      requires_new_transaction: false,
      enum: true,
      create_scopes: false
    }
  end

  def self.human_enum_name(enum_name, enum_value)
    enum_i18n_key = enum_name.to_s.pluralize
    I18n.t("activerecord.attributes.#{model_name.i18n_key}.#{enum_i18n_key}.#{enum_value}")
  end

  def self.human_attr_value(attribute, value)
    attr_i18n_key = attribute.to_s
    I18n.t("activerecord.values.#{model_name.i18n_key}.#{attr_i18n_key}.#{value}")
  end
end
