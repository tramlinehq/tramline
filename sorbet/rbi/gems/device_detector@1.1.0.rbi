# typed: true

# DO NOT EDIT MANUALLY
# This is an autogenerated file for types exported from the `device_detector` gem.
# Please instead update this file by running `bin/tapioca gem device_detector`.


# source://device_detector//lib/device_detector/version.rb#3
class DeviceDetector
  # @return [DeviceDetector] a new instance of DeviceDetector
  #
  # source://device_detector//lib/device_detector.rb#22
  def initialize(user_agent, headers = T.unsafe(nil)); end

  # @return [Boolean]
  #
  # source://device_detector//lib/device_detector.rb#158
  def bot?; end

  # source://device_detector//lib/device_detector.rb#162
  def bot_name; end

  # Returns the value of attribute client_hint.
  #
  # source://device_detector//lib/device_detector.rb#20
  def client_hint; end

  # source://device_detector//lib/device_detector.rb#59
  def device_brand; end

  # source://device_detector//lib/device_detector.rb#55
  def device_name; end

  # source://device_detector//lib/device_detector.rb#66
  def device_type; end

  # source://device_detector//lib/device_detector.rb#33
  def full_version; end

  # @return [Boolean]
  #
  # source://device_detector//lib/device_detector.rb#154
  def known?; end

  # source://device_detector//lib/device_detector.rb#27
  def name; end

  # source://device_detector//lib/device_detector.rb#37
  def os_family; end

  # source://device_detector//lib/device_detector.rb#49
  def os_full_version; end

  # source://device_detector//lib/device_detector.rb#43
  def os_name; end

  # Returns the value of attribute user_agent.
  #
  # source://device_detector//lib/device_detector.rb#20
  def user_agent; end

  private

  # @return [Boolean]
  #
  # source://device_detector//lib/device_detector.rb#232
  def android_mobile_fragment?; end

  # @return [Boolean]
  #
  # source://device_detector//lib/device_detector.rb#228
  def android_tablet_fragment?; end

  # source://device_detector//lib/device_detector.rb#193
  def bot; end

  # source://device_detector//lib/device_detector.rb#274
  def build_regex(src); end

  # source://device_detector//lib/device_detector.rb#197
  def client; end

  # @return [Boolean]
  #
  # source://device_detector//lib/device_detector.rb#265
  def desktop?; end

  # @return [Boolean]
  #
  # source://device_detector//lib/device_detector.rb#236
  def desktop_fragment?; end

  # This is a workaround until we support detecting mobile only browsers
  #
  # @return [Boolean]
  #
  # source://device_detector//lib/device_detector.rb#261
  def desktop_string?; end

  # source://device_detector//lib/device_detector.rb#201
  def device; end

  # Related to issue mentionned in device.rb#1562
  #
  # source://device_detector//lib/device_detector.rb#220
  def fix_for_x_music; end

  # @return [Boolean]
  #
  # source://device_detector//lib/device_detector.rb#215
  def linux_fix?; end

  # https://github.com/matomo-org/device-detector/blob/be1c9ef486c247dc4886668da5ed0b1c49d90ba8/Parser/Client/Browser.php#L772
  # Fix mobile browser names e.g. Chrome => Chrome Mobile
  #
  # @return [Boolean]
  #
  # source://device_detector//lib/device_detector.rb#211
  def mobile_fix?; end

  # @return [Boolean]
  #
  # source://device_detector//lib/device_detector.rb#248
  def opera_tablet?; end

  # @return [Boolean]
  #
  # source://device_detector//lib/device_detector.rb#244
  def opera_tv_store?; end

  # source://device_detector//lib/device_detector.rb#205
  def os; end

  # @return [Boolean]
  #
  # source://device_detector//lib/device_detector.rb#224
  def skip_os_version?; end

  # @return [Boolean]
  #
  # source://device_detector//lib/device_detector.rb#252
  def tizen_samsung_tv?; end

  # @return [Boolean]
  #
  # source://device_detector//lib/device_detector.rb#240
  def touch_enabled?; end

  # @return [Boolean]
  #
  # source://device_detector//lib/device_detector.rb#256
  def uses_mobile_browser?; end

  class << self
    # source://device_detector//lib/device_detector.rb#181
    def cache; end

    # source://device_detector//lib/device_detector.rb#177
    def config; end

    # @yield [config]
    #
    # source://device_detector//lib/device_detector.rb#185
    def configure; end
  end
end

# source://device_detector//lib/device_detector/bot.rb#4
class DeviceDetector::Bot < ::DeviceDetector::Parser
  # @return [Boolean]
  #
  # source://device_detector//lib/device_detector/bot.rb#5
  def bot?; end

  private

  # source://device_detector//lib/device_detector/bot.rb#11
  def filenames; end
end

# source://device_detector//lib/device_detector/browser.rb#4
class DeviceDetector::Browser
  class << self
    # @return [Boolean]
    #
    # source://device_detector//lib/device_detector/browser.rb#530
    def mobile_only_browser?(name); end
  end
end

# source://device_detector//lib/device_detector/browser.rb#5
DeviceDetector::Browser::AVAILABLE_BROWSERS = T.let(T.unsafe(nil), Hash)

# source://device_detector//lib/device_detector/browser.rb#509
DeviceDetector::Browser::BROWSER_FULL_TO_SHORT = T.let(T.unsafe(nil), Hash)

# source://device_detector//lib/device_detector/browser.rb#511
DeviceDetector::Browser::MOBILE_ONLY_BROWSERS = T.let(T.unsafe(nil), Set)

# source://device_detector//lib/device_detector/client.rb#4
class DeviceDetector::Client < ::DeviceDetector::Parser
  # @return [Boolean]
  #
  # source://device_detector//lib/device_detector/client.rb#9
  def browser?; end

  # @return [Boolean]
  #
  # source://device_detector//lib/device_detector/client.rb#5
  def known?; end

  # @return [Boolean]
  #
  # source://device_detector//lib/device_detector/client.rb#13
  def mobile_only_browser?; end

  private

  # source://device_detector//lib/device_detector/client.rb#19
  def filenames; end
end

# source://device_detector//lib/device_detector/client_hint.rb#4
class DeviceDetector::ClientHint
  # @return [ClientHint] a new instance of ClientHint
  #
  # source://device_detector//lib/device_detector/client_hint.rb#13
  def initialize(headers); end

  # Returns the value of attribute app_name.
  #
  # source://device_detector//lib/device_detector/client_hint.rb#25
  def app_name; end

  # Returns the value of attribute browser_list.
  #
  # source://device_detector//lib/device_detector/client_hint.rb#25
  def browser_list; end

  # source://device_detector//lib/device_detector/client_hint.rb#27
  def browser_name; end

  # Returns the value of attribute headers.
  #
  # source://device_detector//lib/device_detector/client_hint.rb#25
  def headers; end

  # Returns the value of attribute mobile.
  #
  # source://device_detector//lib/device_detector/client_hint.rb#25
  def mobile; end

  # Returns the value of attribute model.
  #
  # source://device_detector//lib/device_detector/client_hint.rb#25
  def model; end

  # source://device_detector//lib/device_detector/client_hint.rb#52
  def os_family; end

  # source://device_detector//lib/device_detector/client_hint.rb#39
  def os_name; end

  # source://device_detector//lib/device_detector/client_hint.rb#46
  def os_short_name; end

  # source://device_detector//lib/device_detector/client_hint.rb#33
  def os_version; end

  # Returns the value of attribute platform.
  #
  # source://device_detector//lib/device_detector/client_hint.rb#25
  def platform; end

  # Returns the value of attribute platform_version.
  #
  # source://device_detector//lib/device_detector/client_hint.rb#25
  def platform_version; end

  private

  # https://github.com/matomo-org/device-detector/blob/28211c6f411528abf41304e07b886fdf322a49b7/Parser/OperatingSystem.php#L330
  #
  # @return [Boolean]
  #
  # source://device_detector//lib/device_detector/client_hint.rb#61
  def android_app?; end

  # source://device_detector//lib/device_detector/client_hint.rb#99
  def app_name_from_headers; end

  # source://device_detector//lib/device_detector/client_hint.rb#70
  def available_browsers; end

  # source://device_detector//lib/device_detector/client_hint.rb#74
  def available_osses; end

  # source://device_detector//lib/device_detector/client_hint.rb#66
  def browser_name_from_list; end

  # source://device_detector//lib/device_detector/client_hint.rb#107
  def extract_app_name; end

  # source://device_detector//lib/device_detector/client_hint.rb#134
  def extract_browser_list; end

  # source://device_detector//lib/device_detector/client_hint.rb#160
  def extract_model; end

  # source://device_detector//lib/device_detector/client_hint.rb#114
  def hint_app_names; end

  # source://device_detector//lib/device_detector/client_hint.rb#120
  def hint_filenames; end

  # source://device_detector//lib/device_detector/client_hint.rb#124
  def hint_filepaths; end

  # https://github.com/matomo-org/device-detector/blob/be1c9ef486c247dc4886668da5ed0b1c49d90ba8/Parser/Client/Browser.php#L749
  # If version from client hints report 2022 or 2022.04, then is the Iridium browser
  # https://iridiumbrowser.de/news/2022/05/16/version-2022-04-released
  #
  # @return [Boolean]
  #
  # source://device_detector//lib/device_detector/client_hint.rb#91
  def is_iridium?; end

  # source://device_detector//lib/device_detector/client_hint.rb#130
  def load_hint_app_names; end

  # https://github.com/matomo-org/device-detector/blob/be1c9ef486c247dc4886668da5ed0b1c49d90ba8/Parser/Client/Browser.php#L865
  #
  # source://device_detector//lib/device_detector/client_hint.rb#147
  def name_from_known_browsers(name); end

  # https://github.com/matomo-org/device-detector/blob/28211c6f411528abf41304e07b886fdf322a49b7/Parser/OperatingSystem.php#L434
  #
  # source://device_detector//lib/device_detector/client_hint.rb#79
  def windows_version; end
end

# source://device_detector//lib/device_detector/client_hint.rb#10
class DeviceDetector::ClientHint::HintBrowser < ::Struct; end

# source://device_detector//lib/device_detector/client_hint.rb#7
DeviceDetector::ClientHint::REGEX_CACHE = T.let(T.unsafe(nil), DeviceDetector::MemoryCache)

# source://device_detector//lib/device_detector/client_hint.rb#5
DeviceDetector::ClientHint::ROOT = T.let(T.unsafe(nil), String)

# source://device_detector//lib/device_detector/device.rb#4
class DeviceDetector::Device < ::DeviceDetector::Parser
  # source://device_detector//lib/device_detector/device.rb#1509
  def brand; end

  # @return [Boolean]
  #
  # source://device_detector//lib/device_detector/device.rb#1493
  def known?; end

  # source://device_detector//lib/device_detector/device.rb#1497
  def name; end

  # source://device_detector//lib/device_detector/device.rb#1501
  def type; end

  private

  # The order of files needs to be the same as the order of device
  # parser classes used in the piwik project.
  #
  # source://device_detector//lib/device_detector/device.rb#1517
  def filenames; end

  # @return [Boolean]
  #
  # source://device_detector//lib/device_detector/device.rb#1570
  def hbbtv?; end

  # source://device_detector//lib/device_detector/device.rb#1530
  def matching_regex; end

  # source://device_detector//lib/device_detector/device.rb#1592
  def parse_regexes(path, raw_regexes); end

  # Finds the first match of the string in a list of regexes.
  # Handles exception with special characters caused by bug in Ruby regex
  #
  # @param user_agent [String] User Agent string
  # @param regex_list [Array<Regex>] List of regexes
  # @return [MatchData, nil] MatchData if string matches any regexp, nil otherwise
  #
  # source://device_detector//lib/device_detector/device.rb#1559
  def regex_find(user_agent, regex_list); end

  # source://device_detector//lib/device_detector/device.rb#1580
  def regexes_for_hbbtv; end

  # source://device_detector//lib/device_detector/device.rb#1584
  def regexes_for_shelltv; end

  # source://device_detector//lib/device_detector/device.rb#1588
  def regexes_other; end

  # @return [Boolean]
  #
  # source://device_detector//lib/device_detector/device.rb#1575
  def shelltv?; end
end

# source://device_detector//lib/device_detector/device.rb#23
DeviceDetector::Device::DEVICE_BRANDS = T.let(T.unsafe(nil), Hash)

# order is relevant for testing with fixtures
#
# source://device_detector//lib/device_detector/device.rb#6
DeviceDetector::Device::DEVICE_NAMES = T.let(T.unsafe(nil), Array)

# source://device_detector//lib/device_detector/memory_cache.rb#4
class DeviceDetector::MemoryCache
  # @return [MemoryCache] a new instance of MemoryCache
  #
  # source://device_detector//lib/device_detector/memory_cache.rb#11
  def initialize(config); end

  # Returns the value of attribute data.
  #
  # source://device_detector//lib/device_detector/memory_cache.rb#8
  def data; end

  # source://device_detector//lib/device_detector/memory_cache.rb#27
  def get(key); end

  # source://device_detector//lib/device_detector/memory_cache.rb#32
  def get_or_set(key, value = T.unsafe(nil)); end

  # Returns the value of attribute max_keys.
  #
  # source://device_detector//lib/device_detector/memory_cache.rb#8
  def max_keys; end

  # source://device_detector//lib/device_detector/memory_cache.rb#17
  def set(key, value); end

  private

  # source://device_detector//lib/device_detector/memory_cache.rb#44
  def get_hit(key); end

  # Returns the value of attribute lock.
  #
  # source://device_detector//lib/device_detector/memory_cache.rb#8
  def lock; end

  # source://device_detector//lib/device_detector/memory_cache.rb#51
  def purge_cache; end
end

# source://device_detector//lib/device_detector/memory_cache.rb#5
DeviceDetector::MemoryCache::DEFAULT_MAX_KEYS = T.let(T.unsafe(nil), Integer)

# source://device_detector//lib/device_detector/memory_cache.rb#6
DeviceDetector::MemoryCache::STORES_NIL_VALUE = T.let(T.unsafe(nil), Symbol)

# source://device_detector//lib/device_detector/metadata_extractor.rb#4
class DeviceDetector::MetadataExtractor < ::Struct
  # source://device_detector//lib/device_detector/metadata_extractor.rb#5
  def call; end

  private

  # source://device_detector//lib/device_detector/metadata_extractor.rb#16
  def extract_metadata; end

  # @raise [NotImplementedError]
  #
  # source://device_detector//lib/device_detector/metadata_extractor.rb#11
  def metadata_string; end

  # source://device_detector//lib/device_detector/metadata_extractor.rb#24
  def regex; end
end

# source://device_detector//lib/device_detector/model_extractor.rb#4
class DeviceDetector::ModelExtractor < ::DeviceDetector::MetadataExtractor
  # source://device_detector//lib/device_detector/model_extractor.rb#5
  def call; end

  private

  # source://device_detector//lib/device_detector/model_extractor.rb#16
  def metadata_string; end

  # source://device_detector//lib/device_detector/model_extractor.rb#20
  def regex; end
end

# source://device_detector//lib/device_detector/name_extractor.rb#4
class DeviceDetector::NameExtractor < ::DeviceDetector::MetadataExtractor
  # source://device_detector//lib/device_detector/name_extractor.rb#5
  def call; end

  private

  # source://device_detector//lib/device_detector/name_extractor.rb#15
  def metadata_string; end
end

# source://device_detector//lib/device_detector/os.rb#6
class DeviceDetector::OS < ::DeviceDetector::Parser
  # @return [Boolean]
  #
  # source://device_detector//lib/device_detector/os.rb#19
  def desktop?; end

  # source://device_detector//lib/device_detector/os.rb#15
  def family; end

  # source://device_detector//lib/device_detector/os.rb#23
  def full_version; end

  # source://device_detector//lib/device_detector/os.rb#7
  def name; end

  # source://device_detector//lib/device_detector/os.rb#11
  def short_name; end

  private

  # source://device_detector//lib/device_detector/os.rb#225
  def filenames; end

  # source://device_detector//lib/device_detector/os.rb#30
  def os_info; end
end

# source://device_detector//lib/device_detector/os.rb#42
DeviceDetector::OS::DESKTOP_OSS = T.let(T.unsafe(nil), Set)

# source://device_detector//lib/device_detector/os.rb#183
DeviceDetector::OS::DOWNCASED_OPERATING_SYSTEMS = T.let(T.unsafe(nil), Hash)

# source://device_detector//lib/device_detector/os.rb#221
DeviceDetector::OS::FAMILY_TO_OS = T.let(T.unsafe(nil), Hash)

# OS short codes mapped to long names
#
# source://device_detector//lib/device_detector/os.rb#49
DeviceDetector::OS::OPERATING_SYSTEMS = T.let(T.unsafe(nil), Hash)

# source://device_detector//lib/device_detector/os.rb#187
DeviceDetector::OS::OS_FAMILIES = T.let(T.unsafe(nil), Hash)

# source://device_detector//lib/device_detector/parser.rb#4
class DeviceDetector::Parser
  # @return [Parser] a new instance of Parser
  #
  # source://device_detector//lib/device_detector/parser.rb#10
  def initialize(user_agent); end

  # source://device_detector//lib/device_detector/parser.rb#22
  def full_version; end

  # source://device_detector//lib/device_detector/parser.rb#16
  def name; end

  # Returns the value of attribute user_agent.
  #
  # source://device_detector//lib/device_detector/parser.rb#14
  def user_agent; end

  private

  # source://device_detector//lib/device_detector/parser.rb#87
  def build_regex(src); end

  # @raise [NotImplementedError]
  #
  # source://device_detector//lib/device_detector/parser.rb#44
  def filenames; end

  # source://device_detector//lib/device_detector/parser.rb#48
  def filepaths; end

  # source://device_detector//lib/device_detector/parser.rb#91
  def from_cache(key); end

  # source://device_detector//lib/device_detector/parser.rb#60
  def load_regexes(file_paths); end

  # source://device_detector//lib/device_detector/parser.rb#34
  def matching_regex; end

  # source://device_detector//lib/device_detector/parser.rb#77
  def parse_regexes(path, raw_regexes); end

  # source://device_detector//lib/device_detector/parser.rb#30
  def regex_meta; end

  # source://device_detector//lib/device_detector/parser.rb#40
  def regexes; end

  # source://device_detector//lib/device_detector/parser.rb#54
  def regexes_for(file_paths); end

  # source://device_detector//lib/device_detector/parser.rb#64
  def symbolize_keys!(object); end
end

# source://device_detector//lib/device_detector/parser.rb#7
DeviceDetector::Parser::REGEX_CACHE = T.let(T.unsafe(nil), DeviceDetector::MemoryCache)

# source://device_detector//lib/device_detector/parser.rb#5
DeviceDetector::Parser::ROOT = T.let(T.unsafe(nil), String)

# source://device_detector//lib/device_detector/version.rb#4
DeviceDetector::VERSION = T.let(T.unsafe(nil), String)

# source://device_detector//lib/device_detector/version_extractor.rb#4
class DeviceDetector::VersionExtractor < ::DeviceDetector::MetadataExtractor
  # source://device_detector//lib/device_detector/version_extractor.rb#10
  def call; end

  private

  # source://device_detector//lib/device_detector/version_extractor.rb#35
  def metadata_string; end

  # source://device_detector//lib/device_detector/version_extractor.rb#20
  def os_version_by_regexes; end
end

# source://device_detector//lib/device_detector/version_extractor.rb#5
DeviceDetector::VersionExtractor::MAJOR_VERSION_2 = T.let(T.unsafe(nil), Gem::Version)

# source://device_detector//lib/device_detector/version_extractor.rb#6
DeviceDetector::VersionExtractor::MAJOR_VERSION_3 = T.let(T.unsafe(nil), Gem::Version)

# source://device_detector//lib/device_detector/version_extractor.rb#7
DeviceDetector::VersionExtractor::MAJOR_VERSION_4 = T.let(T.unsafe(nil), Gem::Version)

# source://device_detector//lib/device_detector/version_extractor.rb#8
DeviceDetector::VersionExtractor::MAJOR_VERSION_8 = T.let(T.unsafe(nil), Gem::Version)
