# typed: true

# DO NOT EDIT MANUALLY
# This is an autogenerated file for types exported from the `webdrivers` gem.
# Please instead update this file by running `bin/tapioca gem webdrivers`.


# source://webdrivers//lib/webdrivers/network.rb#5
module Webdrivers
  class << self
    # Returns the amount of time (Seconds) the gem waits between two update checks.
    # are set, it defaults to 86,400 Seconds (24 hours).
    #
    # @note Value from the environment variable "WD_CACHE_TIME" takes precedence over Webdrivers.cache_time. If neither
    #
    # source://webdrivers//lib/webdrivers/common.rb#35
    def cache_time; end

    # Sets the attribute cache_time
    #
    # @param value the value to set the attribute cache_time to.
    #
    # source://webdrivers//lib/webdrivers/common.rb#28
    def cache_time=(_arg0); end

    # Provides a convenient way to configure the gem.
    #
    # @example Configure proxy and cache_time
    #   Webdrivers.configure do |config|
    #   config.proxy_addr = 'myproxy_address.com'
    #   config.proxy_port = '8080'
    #   config.proxy_user = 'username'
    #   config.proxy_pass = 'password'
    #   config.cache_time = 604_800 # 7 days
    #   end
    # @yield [_self]
    # @yieldparam _self [Webdrivers] the object that the method was called on
    #
    # source://webdrivers//lib/webdrivers/common.rb#64
    def configure; end

    # Returns the install (download) directory path for the drivers.
    #
    # @return [String]
    #
    # source://webdrivers//lib/webdrivers/common.rb#44
    def install_dir; end

    # Sets the attribute install_dir
    #
    # @param value the value to set the attribute install_dir to.
    #
    # source://webdrivers//lib/webdrivers/common.rb#28
    def install_dir=(_arg0); end

    # source://webdrivers//lib/webdrivers/common.rb#48
    def logger; end

    # source://webdrivers//lib/webdrivers/common.rb#68
    def net_http_ssl_fix; end

    # Returns the value of attribute proxy_addr.
    #
    # source://webdrivers//lib/webdrivers/common.rb#27
    def proxy_addr; end

    # Sets the attribute proxy_addr
    #
    # @param value the value to set the attribute proxy_addr to.
    #
    # source://webdrivers//lib/webdrivers/common.rb#27
    def proxy_addr=(_arg0); end

    # Returns the value of attribute proxy_pass.
    #
    # source://webdrivers//lib/webdrivers/common.rb#27
    def proxy_pass; end

    # Sets the attribute proxy_pass
    #
    # @param value the value to set the attribute proxy_pass to.
    #
    # source://webdrivers//lib/webdrivers/common.rb#27
    def proxy_pass=(_arg0); end

    # Returns the value of attribute proxy_port.
    #
    # source://webdrivers//lib/webdrivers/common.rb#27
    def proxy_port; end

    # Sets the attribute proxy_port
    #
    # @param value the value to set the attribute proxy_port to.
    #
    # source://webdrivers//lib/webdrivers/common.rb#27
    def proxy_port=(_arg0); end

    # Returns the value of attribute proxy_user.
    #
    # source://webdrivers//lib/webdrivers/common.rb#27
    def proxy_user; end

    # Sets the attribute proxy_user
    #
    # @param value the value to set the attribute proxy_user to.
    #
    # source://webdrivers//lib/webdrivers/common.rb#27
    def proxy_user=(_arg0); end
  end
end

# source://webdrivers//lib/webdrivers/common.rb#20
class Webdrivers::BrowserNotFound < ::StandardError; end

# @api private
#
# source://webdrivers//lib/webdrivers/chrome_finder.rb#7
class Webdrivers::ChromeFinder
  class << self
    # @api private
    # @raise [BrowserNotFound]
    #
    # source://webdrivers//lib/webdrivers/chrome_finder.rb#17
    def location; end

    # @api private
    # @raise [VersionError]
    #
    # source://webdrivers//lib/webdrivers/chrome_finder.rb#9
    def version; end

    private

    # @api private
    #
    # source://webdrivers//lib/webdrivers/chrome_finder.rb#90
    def linux_location; end

    # @api private
    #
    # source://webdrivers//lib/webdrivers/chrome_finder.rb#126
    def linux_version(location); end

    # @api private
    #
    # source://webdrivers//lib/webdrivers/chrome_finder.rb#75
    def mac_location; end

    # @api private
    #
    # source://webdrivers//lib/webdrivers/chrome_finder.rb#132
    def mac_version(location); end

    # @api private
    #
    # source://webdrivers//lib/webdrivers/chrome_finder.rb#26
    def user_defined_location; end

    # @api private
    #
    # source://webdrivers//lib/webdrivers/chrome_finder.rb#38
    def win_location; end

    # @api private
    #
    # source://webdrivers//lib/webdrivers/chrome_finder.rb#116
    def win_version(location); end

    # @api private
    #
    # source://webdrivers//lib/webdrivers/chrome_finder.rb#53
    def wsl_location; end

    # @api private
    #
    # source://webdrivers//lib/webdrivers/chrome_finder.rb#122
    def wsl_version(location); end
  end
end

# source://webdrivers//lib/webdrivers/chromedriver.rb#8
class Webdrivers::Chromedriver < ::Webdrivers::Common
  class << self
    # Returns url with domain for calls to get this driver.
    #
    # @return [String]
    #
    # source://webdrivers//lib/webdrivers/chromedriver.rb#59
    def base_url; end

    # Returns currently installed Chrome/Chromium version.
    #
    # @return [Gem::Version]
    #
    # source://webdrivers//lib/webdrivers/chromedriver.rb#50
    def browser_version; end

    # Returns currently installed Chrome/Chromium version.
    #
    # @return [Gem::Version]
    #
    # source://webdrivers//lib/webdrivers/chromedriver.rb#50
    def chrome_version; end

    # Returns current chromedriver version.
    #
    # @return [Gem::Version]
    #
    # source://webdrivers//lib/webdrivers/chromedriver.rb#14
    def current_version; end

    # Returns latest available chromedriver version.
    #
    # @return [Gem::Version]
    #
    # source://webdrivers//lib/webdrivers/chromedriver.rb#29
    def latest_version; end

    private

    # source://webdrivers//lib/webdrivers/chromedriver.rb#100
    def apple_filename(driver_version); end

    # @return [Boolean]
    #
    # source://webdrivers//lib/webdrivers/chromedriver.rb#90
    def apple_m1_compatible?(driver_version); end

    # Returns major.minor.build version from the currently installed Chrome version
    #
    # @example
    #   73.0.3683.75 (major.minor.build.patch) -> 73.0.3683 (major.minor.build)
    #
    # source://webdrivers//lib/webdrivers/chromedriver.rb#141
    def browser_build_version; end

    # Returns major.minor.build version from the currently installed Chrome version
    #
    # @example
    #   73.0.3683.75 (major.minor.build.patch) -> 73.0.3683 (major.minor.build)
    #
    # source://webdrivers//lib/webdrivers/chromedriver.rb#141
    def chrome_build_version; end

    # Returns major.minor.build version from the currently installed chromedriver version
    #
    # @example
    #   73.0.3683.68 (major.minor.build.patch) -> 73.0.3683 (major.minor.build)
    #
    # source://webdrivers//lib/webdrivers/chromedriver.rb#128
    def current_build_version; end

    # source://webdrivers//lib/webdrivers/chromedriver.rb#108
    def direct_url(driver_version); end

    # source://webdrivers//lib/webdrivers/chromedriver.rb#112
    def driver_filename(driver_version); end

    # source://webdrivers//lib/webdrivers/chromedriver.rb#86
    def file_name; end

    # source://webdrivers//lib/webdrivers/chromedriver.rb#65
    def latest_point_release(version); end

    # Returns true if an executable driver binary exists
    # and its build version matches the browser build version
    #
    # @return [Boolean]
    #
    # source://webdrivers//lib/webdrivers/chromedriver.rb#148
    def sufficient_binary?; end
  end
end

# source://webdrivers//lib/webdrivers/common.rb#74
class Webdrivers::Common
  class << self
    # Returns path to the driver binary.
    #
    # @return [String]
    #
    # source://webdrivers//lib/webdrivers/common.rb#115
    def driver_path; end

    # Deletes the existing driver binary.
    #
    # source://webdrivers//lib/webdrivers/common.rb#104
    def remove; end

    # Returns the user defined required version.
    #
    # @return [Gem::Version]
    #
    # source://webdrivers//lib/webdrivers/common.rb#82
    def required_version; end

    # Sets the attribute required_version
    #
    # @param value the value to set the attribute required_version to.
    #
    # source://webdrivers//lib/webdrivers/common.rb#76
    def required_version=(_arg0); end

    # Triggers an update check.
    #
    # @return [String] Path to the driver binary.
    #
    # source://webdrivers//lib/webdrivers/common.rb#90
    def update; end

    private

    # source://webdrivers//lib/webdrivers/common.rb#147
    def binary_version; end

    # @return [Boolean]
    #
    # source://webdrivers//lib/webdrivers/common.rb#133
    def correct_binary?; end

    # source://webdrivers//lib/webdrivers/common.rb#125
    def download_url; end

    # source://webdrivers//lib/webdrivers/common.rb#121
    def download_version; end

    # @return [Boolean]
    #
    # source://webdrivers//lib/webdrivers/common.rb#129
    def exists?; end

    # source://webdrivers//lib/webdrivers/common.rb#143
    def normalize_version(version); end

    # @return [Boolean]
    #
    # source://webdrivers//lib/webdrivers/common.rb#139
    def sufficient_binary?; end

    # Returns cached driver version if cache is still valid and the driver binary exists.
    # Otherwise caches the given version (typically the latest available)
    # In case of Chrome, it also verifies that the driver build and browser build versions are compatible.
    # Example usage: lib/webdrivers/chromedriver.rb:34
    #
    # source://webdrivers//lib/webdrivers/common.rb#160
    def with_cache(file_name, driver_build = T.unsafe(nil), browser_build = T.unsafe(nil)); end
  end
end

# source://webdrivers//lib/webdrivers/common.rb#11
class Webdrivers::ConnectionError < ::StandardError; end

# 24 hours
#
# source://webdrivers//lib/webdrivers/common.rb#23
Webdrivers::DEFAULT_CACHE_TIME = T.let(T.unsafe(nil), Integer)

# source://webdrivers//lib/webdrivers/common.rb#24
Webdrivers::DEFAULT_INSTALL_DIR = T.let(T.unsafe(nil), String)

# @api private
#
# source://webdrivers//lib/webdrivers/edge_finder.rb#7
class Webdrivers::EdgeFinder
  class << self
    # @api private
    # @raise [BrowserNotFound]
    #
    # source://webdrivers//lib/webdrivers/edge_finder.rb#17
    def location; end

    # @api private
    # @raise [VersionError]
    #
    # source://webdrivers//lib/webdrivers/edge_finder.rb#9
    def version; end

    private

    # @api private
    #
    # source://webdrivers//lib/webdrivers/edge_finder.rb#71
    def linux_location; end

    # @api private
    #
    # source://webdrivers//lib/webdrivers/edge_finder.rb#89
    def linux_version(location); end

    # @api private
    #
    # source://webdrivers//lib/webdrivers/edge_finder.rb#55
    def mac_location; end

    # @api private
    #
    # source://webdrivers//lib/webdrivers/edge_finder.rb#93
    def mac_version(location); end

    # @api private
    #
    # source://webdrivers//lib/webdrivers/edge_finder.rb#26
    def user_defined_location; end

    # @api private
    #
    # source://webdrivers//lib/webdrivers/edge_finder.rb#38
    def win_location; end

    # @api private
    #
    # source://webdrivers//lib/webdrivers/edge_finder.rb#85
    def win_version(location); end
  end
end

# source://webdrivers//lib/webdrivers/edgedriver.rb#9
class Webdrivers::Edgedriver < ::Webdrivers::Chromedriver
  class << self
    # Returns url with domain for calls to get this driver.
    #
    # @return [String]
    #
    # source://webdrivers//lib/webdrivers/edgedriver.rb#24
    def base_url; end

    # Returns currently installed Edge version.
    #
    # @return [Gem::Version]
    #
    # source://webdrivers//lib/webdrivers/edgedriver.rb#16
    def browser_version; end

    private

    # @return [Boolean]
    #
    # source://webdrivers//lib/webdrivers/edgedriver.rb#68
    def apple_m1_compatible?(driver_version); end

    # source://webdrivers//lib/webdrivers/edgedriver.rb#92
    def direct_url(driver_version); end

    # source://webdrivers//lib/webdrivers/edgedriver.rb#78
    def driver_filename(driver_version); end

    # source://webdrivers//lib/webdrivers/edgedriver.rb#44
    def failed_to_find_message(version); end

    # source://webdrivers//lib/webdrivers/edgedriver.rb#64
    def file_name; end

    # source://webdrivers//lib/webdrivers/edgedriver.rb#30
    def latest_point_release(version); end
  end
end

# source://webdrivers//lib/webdrivers/geckodriver.rb#7
class Webdrivers::Geckodriver < ::Webdrivers::Common
  class << self
    # Returns url with domain for calls to get this driver.
    #
    # @return [String]
    #
    # source://webdrivers//lib/webdrivers/geckodriver.rb#35
    def base_url; end

    # Returns current geckodriver version.
    #
    # @return [Gem::Version]
    #
    # source://webdrivers//lib/webdrivers/geckodriver.rb#13
    def current_version; end

    # Returns latest available geckodriver version.
    #
    # @return [Gem::Version]
    #
    # source://webdrivers//lib/webdrivers/geckodriver.rb#27
    def latest_version; end

    private

    # source://webdrivers//lib/webdrivers/geckodriver.rb#45
    def direct_url(version); end

    # source://webdrivers//lib/webdrivers/geckodriver.rb#41
    def file_name; end

    # source://webdrivers//lib/webdrivers/geckodriver.rb#49
    def platform_ext; end
  end
end

# source://webdrivers//lib/webdrivers/iedriver.rb#8
class Webdrivers::IEdriver < ::Webdrivers::Common
  class << self
    # Returns url with domain for calls to get this driver.
    #
    # @return [String]
    #
    # source://webdrivers//lib/webdrivers/iedriver.rb#36
    def base_url; end

    # Returns current IEDriverServer.exe version.
    #
    # @return [Gem::Version]
    #
    # source://webdrivers//lib/webdrivers/iedriver.rb#14
    def current_version; end

    # Returns latest available IEDriverServer.exe version.
    #
    # @return [Gem::Version]
    #
    # source://webdrivers//lib/webdrivers/iedriver.rb#28
    def latest_version; end

    private

    # source://webdrivers//lib/webdrivers/iedriver.rb#46
    def direct_url(version); end

    # source://webdrivers//lib/webdrivers/iedriver.rb#59
    def download_manifest; end

    # source://webdrivers//lib/webdrivers/iedriver.rb#50
    def downloads; end

    # source://webdrivers//lib/webdrivers/iedriver.rb#42
    def file_name; end
  end
end

# @example Enable full logging
#   Webdrivers.logger.level = :debug
# @example Log to file
#   Webdrivers.logger.output = 'webdrivers.log'
# @example Use logger manually
#   Webdrivers.logger.info('This is info message')
#   Webdrivers.logger.warn('This is warning message')
#
# source://webdrivers//lib/webdrivers/logger.rb#15
class Webdrivers::Logger < ::Selenium::WebDriver::Logger
  # @return [Logger] a new instance of Logger
  #
  # source://webdrivers//lib/webdrivers/logger.rb#16
  def initialize; end
end

# @api private
#
# source://webdrivers//lib/webdrivers/network.rb#9
class Webdrivers::Network
  class << self
    # @api private
    #
    # source://webdrivers//lib/webdrivers/network.rb#11
    def get(url, limit = T.unsafe(nil)); end

    # @api private
    # @raise [ConnectionError]
    #
    # source://webdrivers//lib/webdrivers/network.rb#29
    def get_response(url, limit = T.unsafe(nil)); end

    # @api private
    #
    # source://webdrivers//lib/webdrivers/network.rb#23
    def get_url(url, limit = T.unsafe(nil)); end

    # @api private
    #
    # source://webdrivers//lib/webdrivers/network.rb#49
    def http; end

    # @api private
    #
    # source://webdrivers//lib/webdrivers/network.rb#58
    def using_proxy; end
  end
end

# source://webdrivers//lib/webdrivers/common.rb#17
class Webdrivers::NetworkError < ::StandardError; end

# source://webdrivers//lib/webdrivers/railtie.rb#6
class Webdrivers::Railtie < ::Rails::Railtie; end

# @api private
#
# source://webdrivers//lib/webdrivers/system.rb#17
class Webdrivers::System
  class << self
    # @api private
    # @return [Boolean]
    #
    # source://webdrivers//lib/webdrivers/system.rb#151
    def apple_m1_architecture?; end

    # @api private
    #
    # source://webdrivers//lib/webdrivers/system.rb#180
    def bitsize; end

    # @api private
    #
    # source://webdrivers//lib/webdrivers/system.rb#41
    def cache_version(file_name, version); end

    # @api private
    #
    # source://webdrivers//lib/webdrivers/system.rb#49
    def cached_version(file_name); end

    # @api private
    #
    # source://webdrivers//lib/webdrivers/system.rb#184
    def call(process, arg = T.unsafe(nil)); end

    # @api private
    #
    # source://webdrivers//lib/webdrivers/system.rb#93
    def decompress_file(tempfile, file_name, target); end

    # @api private
    #
    # source://webdrivers//lib/webdrivers/system.rb#19
    def delete(file); end

    # @api private
    #
    # source://webdrivers//lib/webdrivers/system.rb#60
    def download(url, target); end

    # @api private
    #
    # source://webdrivers//lib/webdrivers/system.rb#70
    def download_file(url, target); end

    # @api private
    # @return [Boolean]
    #
    # source://webdrivers//lib/webdrivers/system.rb#87
    def exists?(file); end

    # @api private
    #
    # source://webdrivers//lib/webdrivers/system.rb#37
    def install_dir; end

    # @api private
    #
    # source://webdrivers//lib/webdrivers/system.rb#139
    def platform; end

    # @api private
    # @param path [String]
    # @return [String]
    #
    # source://webdrivers//lib/webdrivers/system.rb#168
    def to_win32_path(path); end

    # @api private
    # @param path [String]
    # @return [String]
    #
    # source://webdrivers//lib/webdrivers/system.rb#176
    def to_wsl_path(path); end

    # @api private
    #
    # source://webdrivers//lib/webdrivers/system.rb#109
    def untarbz2_file(filename); end

    # @api private
    #
    # source://webdrivers//lib/webdrivers/system.rb#115
    def untargz_file(source, target); end

    # @api private
    #
    # source://webdrivers//lib/webdrivers/system.rb#126
    def unzip_file(filename, driver_name); end

    # @api private
    # @return [Boolean]
    #
    # source://webdrivers//lib/webdrivers/system.rb#53
    def valid_cache?(file_name); end

    # @api private
    # @return [TrueClass, FalseClass]
    #
    # source://webdrivers//lib/webdrivers/system.rb#162
    def wsl_v1?; end
  end
end

# source://webdrivers//lib/webdrivers/version.rb#4
Webdrivers::VERSION = T.let(T.unsafe(nil), String)

# source://webdrivers//lib/webdrivers/common.rb#14
class Webdrivers::VersionError < ::StandardError; end
