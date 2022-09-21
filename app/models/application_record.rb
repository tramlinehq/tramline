class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class
  self.implicit_order_column = :created_at
end
