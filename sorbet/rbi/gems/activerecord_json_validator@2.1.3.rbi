# typed: true

# DO NOT EDIT MANUALLY
# This is an autogenerated file for types exported from the `activerecord_json_validator` gem.
# Please instead update this file by running `bin/tapioca gem activerecord_json_validator`.


# source://activerecord_json_validator//lib/active_record/json_validator/version.rb#3
module ActiveRecord
  class << self
    # source://activerecord/7.0.8.4/lib/active_record.rb#277
    def action_on_strict_loading_violation; end

    # source://activerecord/7.0.8.4/lib/active_record.rb#277
    def action_on_strict_loading_violation=(_arg0); end

    # source://activerecord/7.0.8.4/lib/active_record.rb#270
    def application_record_class; end

    # source://activerecord/7.0.8.4/lib/active_record.rb#270
    def application_record_class=(_arg0); end

    # source://activerecord/7.0.8.4/lib/active_record.rb#213
    def async_query_executor; end

    # source://activerecord/7.0.8.4/lib/active_record.rb#213
    def async_query_executor=(_arg0); end

    # source://activerecord/7.0.8.4/lib/active_record.rb#183
    def default_timezone; end

    # source://activerecord/7.0.8.4/lib/active_record.rb#187
    def default_timezone=(default_timezone); end

    # source://activerecord/7.0.8.4/lib/active_record.rb#311
    def dump_schema_after_migration; end

    # source://activerecord/7.0.8.4/lib/active_record.rb#311
    def dump_schema_after_migration=(_arg0); end

    # source://activerecord/7.0.8.4/lib/active_record.rb#321
    def dump_schemas; end

    # source://activerecord/7.0.8.4/lib/active_record.rb#321
    def dump_schemas=(_arg0); end

    # source://activerecord/7.0.8.4/lib/active_record.rb#365
    def eager_load!; end

    # source://activerecord/7.0.8.4/lib/active_record.rb#296
    def error_on_ignored_order; end

    # source://activerecord/7.0.8.4/lib/active_record.rb#296
    def error_on_ignored_order=(_arg0); end

    # source://activerecord/7.0.8.4/lib/active_record/gem_version.rb#5
    def gem_version; end

    # source://activerecord/7.0.8.4/lib/active_record.rb#236
    def global_executor_concurrency; end

    # source://activerecord/7.0.8.4/lib/active_record.rb#228
    def global_executor_concurrency=(global_executor_concurrency); end

    # source://activerecord/7.0.8.4/lib/active_record.rb#216
    def global_thread_pool_async_query_executor; end

    # source://activerecord/7.0.8.4/lib/active_record.rb#240
    def index_nested_attribute_errors; end

    # source://activerecord/7.0.8.4/lib/active_record.rb#240
    def index_nested_attribute_errors=(_arg0); end

    # source://activerecord/7.0.8.4/lib/active_record.rb#171
    def lazily_load_schema_cache; end

    # source://activerecord/7.0.8.4/lib/active_record.rb#171
    def lazily_load_schema_cache=(_arg0); end

    # source://activerecord/7.0.8.4/lib/active_record.rb#180
    def legacy_connection_handling; end

    # source://activerecord/7.0.8.4/lib/active_record.rb#180
    def legacy_connection_handling=(_arg0); end

    # source://activerecord/7.0.8.4/lib/active_record.rb#258
    def maintain_test_schema; end

    # source://activerecord/7.0.8.4/lib/active_record.rb#258
    def maintain_test_schema=(_arg0); end

    # source://activerecord/7.0.8.4/lib/active_record.rb#340
    def query_transformers; end

    # source://activerecord/7.0.8.4/lib/active_record.rb#340
    def query_transformers=(_arg0); end

    # source://activerecord/7.0.8.4/lib/active_record.rb#255
    def queues; end

    # source://activerecord/7.0.8.4/lib/active_record.rb#255
    def queues=(_arg0); end

    # source://activerecord/7.0.8.4/lib/active_record.rb#355
    def raise_int_wider_than_64bit; end

    # source://activerecord/7.0.8.4/lib/active_record.rb#355
    def raise_int_wider_than_64bit=(_arg0); end

    # source://activerecord/7.0.8.4/lib/active_record.rb#200
    def reading_role; end

    # source://activerecord/7.0.8.4/lib/active_record.rb#200
    def reading_role=(_arg0); end

    # source://activerecord/7.0.8.4/lib/active_record.rb#177
    def schema_cache_ignored_tables; end

    # source://activerecord/7.0.8.4/lib/active_record.rb#177
    def schema_cache_ignored_tables=(_arg0); end

    # source://activerecord/7.0.8.4/lib/active_record.rb#288
    def schema_format; end

    # source://activerecord/7.0.8.4/lib/active_record.rb#288
    def schema_format=(_arg0); end

    # source://activerecord/7.0.8.4/lib/active_record.rb#328
    def suppress_multiple_database_warning; end

    # source://activerecord/7.0.8.4/lib/active_record.rb#328
    def suppress_multiple_database_warning=(_arg0); end

    # source://activerecord/7.0.8.4/lib/active_record.rb#302
    def timestamped_migrations; end

    # source://activerecord/7.0.8.4/lib/active_record.rb#302
    def timestamped_migrations=(_arg0); end

    # source://activerecord/7.0.8.4/lib/active_record.rb#347
    def use_yaml_unsafe_load; end

    # source://activerecord/7.0.8.4/lib/active_record.rb#347
    def use_yaml_unsafe_load=(_arg0); end

    # source://activerecord/7.0.8.4/lib/active_record.rb#248
    def verbose_query_logs; end

    # source://activerecord/7.0.8.4/lib/active_record.rb#248
    def verbose_query_logs=(_arg0); end

    # source://activerecord/7.0.8.4/lib/active_record.rb#337
    def verify_foreign_keys_for_fixtures; end

    # source://activerecord/7.0.8.4/lib/active_record.rb#337
    def verify_foreign_keys_for_fixtures=(_arg0); end

    # source://activerecord/7.0.8.4/lib/active_record/version.rb#7
    def version; end

    # source://activerecord/7.0.8.4/lib/active_record.rb#267
    def warn_on_records_fetched_greater_than; end

    # source://activerecord/7.0.8.4/lib/active_record.rb#267
    def warn_on_records_fetched_greater_than=(_arg0); end

    # source://activerecord/7.0.8.4/lib/active_record.rb#197
    def writing_role; end

    # source://activerecord/7.0.8.4/lib/active_record.rb#197
    def writing_role=(_arg0); end

    # source://activerecord/7.0.8.4/lib/active_record.rb#362
    def yaml_column_permitted_classes; end

    # source://activerecord/7.0.8.4/lib/active_record.rb#362
    def yaml_column_permitted_classes=(_arg0); end
  end
end

# source://activerecord_json_validator//lib/active_record/json_validator/version.rb#4
module ActiveRecord::JSONValidator; end

# source://activerecord_json_validator//lib/active_record/json_validator/version.rb#5
ActiveRecord::JSONValidator::VERSION = T.let(T.unsafe(nil), String)

# NOTE: In case `"JSON"` is treated as an acronym by `ActiveSupport::Inflector`,
# make `JSONValidator` available too.
#
# source://activerecord_json_validator//lib/activerecord_json_validator.rb#11
JSONValidator = JsonValidator

# source://activerecord_json_validator//lib/active_record/json_validator/validator.rb#3
class JsonValidator < ::ActiveModel::EachValidator
  # @return [JsonValidator] a new instance of JsonValidator
  #
  # source://activerecord_json_validator//lib/active_record/json_validator/validator.rb#4
  def initialize(options); end

  # Validate the JSON value with a JSON schema path or String
  #
  # source://activerecord_json_validator//lib/active_record/json_validator/validator.rb#17
  def validate_each(record, attribute, value); end

  protected

  # Redefine the setter method for the attributes, since we want to
  # catch JSON parsing errors.
  #
  # source://activerecord_json_validator//lib/active_record/json_validator/validator.rb#38
  def inject_setter_method(klass, attributes); end

  # source://activerecord_json_validator//lib/active_record/json_validator/validator.rb#69
  def message(errors); end

  # Return a valid schema, recursively calling
  # itself until it gets a non-Proc/non-Symbol value.
  #
  # source://activerecord_json_validator//lib/active_record/json_validator/validator.rb#59
  def schema(record, schema = T.unsafe(nil)); end
end
