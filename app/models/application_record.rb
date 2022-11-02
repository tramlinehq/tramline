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
end
