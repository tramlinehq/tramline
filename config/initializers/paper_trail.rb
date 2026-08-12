# PaperTrail's YAML serializer deserializes version payloads with Psych's
# safe_load (the Ruby 3.4 / Psych 4 default), permitting only the classes in
# ActiveRecord.yaml_column_permitted_classes (just [Symbol] by default). Existing
# `versions` rows contain time/date/decimal/hash values, so without permitting
# these classes, reading historical audit data raises Psych::DisallowedClass.
ActiveRecord.yaml_column_permitted_classes |= [
  BigDecimal, Date, Time, DateTime,
  ActiveSupport::TimeWithZone, ActiveSupport::TimeZone,
  ActiveSupport::HashWithIndifferentAccess
]
