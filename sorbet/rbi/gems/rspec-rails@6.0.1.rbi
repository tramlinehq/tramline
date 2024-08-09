# typed: true

# DO NOT EDIT MANUALLY
# This is an autogenerated file for types exported from the `rspec-rails` gem.
# Please instead update this file by running `bin/tapioca gem rspec-rails`.


# Namespace for all core RSpec projects.
#
# source://rspec-rails//lib/rspec/rails/feature_check.rb#1
module RSpec; end

# Namespace for rspec-rails code.
#
# source://rspec-rails//lib/rspec/rails/feature_check.rb#2
module RSpec::Rails; end

# @private
#
# source://rspec-rails//lib/rspec/rails/feature_check.rb#4
module RSpec::Rails::FeatureCheck
  private

  # source://rspec-rails//lib/rspec/rails/feature_check.rb#26
  def has_action_cable_testing?; end

  # source://rspec-rails//lib/rspec/rails/feature_check.rb#42
  def has_action_mailbox?; end

  # source://rspec-rails//lib/rspec/rails/feature_check.rb#18
  def has_action_mailer?; end

  # source://rspec-rails//lib/rspec/rails/feature_check.rb#38
  def has_action_mailer_legacy_delivery_job?; end

  # source://rspec-rails//lib/rspec/rails/feature_check.rb#30
  def has_action_mailer_parameterized?; end

  # source://rspec-rails//lib/rspec/rails/feature_check.rb#22
  def has_action_mailer_preview?; end

  # source://rspec-rails//lib/rspec/rails/feature_check.rb#34
  def has_action_mailer_unified_delivery?; end

  # source://rspec-rails//lib/rspec/rails/feature_check.rb#6
  def has_active_job?; end

  # source://rspec-rails//lib/rspec/rails/feature_check.rb#10
  def has_active_record?; end

  # source://rspec-rails//lib/rspec/rails/feature_check.rb#14
  def has_active_record_migration?; end

  # source://rspec-rails//lib/rspec/rails/feature_check.rb#46
  def type_metatag(type); end

  class << self
    # @return [Boolean]
    #
    # source://rspec-rails//lib/rspec/rails/feature_check.rb#26
    def has_action_cable_testing?; end

    # @return [Boolean]
    #
    # source://rspec-rails//lib/rspec/rails/feature_check.rb#42
    def has_action_mailbox?; end

    # @return [Boolean]
    #
    # source://rspec-rails//lib/rspec/rails/feature_check.rb#18
    def has_action_mailer?; end

    # @return [Boolean]
    #
    # source://rspec-rails//lib/rspec/rails/feature_check.rb#38
    def has_action_mailer_legacy_delivery_job?; end

    # @return [Boolean]
    #
    # source://rspec-rails//lib/rspec/rails/feature_check.rb#30
    def has_action_mailer_parameterized?; end

    # @return [Boolean]
    #
    # source://rspec-rails//lib/rspec/rails/feature_check.rb#22
    def has_action_mailer_preview?; end

    # @return [Boolean]
    #
    # source://rspec-rails//lib/rspec/rails/feature_check.rb#34
    def has_action_mailer_unified_delivery?; end

    # @return [Boolean]
    #
    # source://rspec-rails//lib/rspec/rails/feature_check.rb#6
    def has_active_job?; end

    # @return [Boolean]
    #
    # source://rspec-rails//lib/rspec/rails/feature_check.rb#10
    def has_active_record?; end

    # @return [Boolean]
    #
    # source://rspec-rails//lib/rspec/rails/feature_check.rb#14
    def has_active_record_migration?; end

    # source://rspec-rails//lib/rspec/rails/feature_check.rb#46
    def type_metatag(type); end
  end
end

# Railtie to hook into Rails.
#
# source://rspec-rails//lib/rspec-rails.rb#8
class RSpec::Rails::Railtie < ::Rails::Railtie
  private

  # source://rspec-rails//lib/rspec-rails.rb#50
  def config_default_preview_path(options); end

  # @return [Boolean]
  #
  # source://rspec-rails//lib/rspec-rails.rb#40
  def config_preview_path?(options); end

  # source://rspec-rails//lib/rspec-rails.rb#33
  def setup_preview_path(app); end

  # @return [Boolean]
  #
  # source://rspec-rails//lib/rspec-rails.rb#56
  def supports_action_mailer_previews?(config); end
end
