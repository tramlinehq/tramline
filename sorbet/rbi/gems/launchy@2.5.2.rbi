# typed: true

# DO NOT EDIT MANUALLY
# This is an autogenerated file for types exported from the `launchy` gem.
# Please instead update this file by running `bin/tapioca gem launchy`.


# The entry point into Launchy. This is the sole supported public API.
#
#   Launchy.open( uri, options = {} )
#
# The currently defined global options are:
#
#   :debug        Turn on debugging output
#   :application  Explicitly state what application class is going to be used.
#                 This must be a child class of Launchy::Application
#   :host_os      Explicitly state what host operating system to pretend to be
#   :ruby_engine  Explicitly state what ruby engine to pretend to be under
#   :dry_run      Do nothing and print the command that would be executed on $stdout
#
# Other options may be used, and those will be passed directly to the
# application class
#
# source://launchy//lib/launchy.rb#20
module Launchy
  class << self
    # source://launchy//lib/launchy.rb#43
    def app_for_uri(uri); end

    # source://launchy//lib/launchy.rb#47
    def app_for_uri_string(s); end

    # source://launchy//lib/launchy.rb#95
    def application; end

    # source://launchy//lib/launchy.rb#91
    def application=(app); end

    # source://launchy//lib/launchy.rb#123
    def bug_report_message; end

    # source://launchy//lib/launchy.rb#81
    def debug=(d); end

    # we may do logging before a call to 'open', hence the need to check
    # LAUNCHY_DEBUG here
    #
    # @return [Boolean]
    #
    # source://launchy//lib/launchy.rb#87
    def debug?; end

    # source://launchy//lib/launchy.rb#115
    def dry_run=(dry_run); end

    # @return [Boolean]
    #
    # source://launchy//lib/launchy.rb#119
    def dry_run?; end

    # source://launchy//lib/launchy.rb#72
    def extract_global_options(options); end

    # source://launchy//lib/launchy.rb#103
    def host_os; end

    # source://launchy//lib/launchy.rb#99
    def host_os=(host_os); end

    # source://launchy//lib/launchy.rb#127
    def log(msg); end

    # Launch an application for the given uri string
    #
    # source://launchy//lib/launchy.rb#26
    def open(uri_s, options = T.unsafe(nil), &error_block); end

    # source://launchy//lib/launchy.rb#131
    def path; end

    # source://launchy//lib/launchy.rb#135
    def path=(path); end

    # source://launchy//lib/launchy.rb#63
    def reset_global_options; end

    # source://launchy//lib/launchy.rb#111
    def ruby_engine; end

    # source://launchy//lib/launchy.rb#107
    def ruby_engine=(ruby_engine); end

    # @raise [Launchy::ArgumentError]
    #
    # source://launchy//lib/launchy.rb#51
    def string_to_uri(s); end

    private

    # source://launchy//lib/launchy.rb#140
    def to_bool(arg); end
  end
end

# Application is the base class of all the application types that launchy may
# invoke. It essentially defines the public api of the launchy system.
#
# Every class that inherits from Application must define:
#
# 1. A constructor taking no parameters
# 2. An instance method 'open' taking a string or URI as the first parameter and a
#    hash as the second
# 3. A class method 'handles?' that takes a String and returns true if that
#    class can handle the input.
#
# source://launchy//lib/launchy/application.rb#14
class Launchy::Application
  extend ::Launchy::DescendantTracker

  # @return [Application] a new instance of Application
  #
  # source://launchy//lib/launchy/application.rb#47
  def initialize; end

  # source://launchy//lib/launchy/application.rb#53
  def find_executable(bin, *paths); end

  # Returns the value of attribute host_os_family.
  #
  # source://launchy//lib/launchy/application.rb#43
  def host_os_family; end

  # Returns the value of attribute ruby_engine.
  #
  # source://launchy//lib/launchy/application.rb#44
  def ruby_engine; end

  # source://launchy//lib/launchy/application.rb#57
  def run(cmd, *args); end

  # Returns the value of attribute runner.
  #
  # source://launchy//lib/launchy/application.rb#45
  def runner; end

  class << self
    # Find the given executable in the available paths
    #
    # source://launchy//lib/launchy/application.rb#29
    def find_executable(bin, *paths); end

    # Find the application that handles the given uri.
    #
    # returns the Class that can handle the uri
    #
    # @raise [ApplicationNotFoundError]
    #
    # source://launchy//lib/launchy/application.rb#21
    def handling(uri); end
  end
end

# The class handling the browser application and all of its schemes
#
# source://launchy//lib/launchy/applications/browser.rb#5
class Launchy::Application::Browser < ::Launchy::Application
  # use a call back mechanism to get the right app_list that is decided by the
  # host_os_family class.
  #
  # source://launchy//lib/launchy/applications/browser.rb#36
  def app_list; end

  # Get the full commandline of what we are going to add the uri to
  #
  # @raise [Launchy::CommandNotFoundError]
  #
  # source://launchy//lib/launchy/applications/browser.rb#49
  def browser_cmdline; end

  # source://launchy//lib/launchy/applications/browser.rb#40
  def browser_env; end

  # source://launchy//lib/launchy/applications/browser.rb#66
  def cmd_and_args(uri, options = T.unsafe(nil)); end

  # source://launchy//lib/launchy/applications/browser.rb#19
  def cygwin_app_list; end

  # hardcode this to open?
  #
  # source://launchy//lib/launchy/applications/browser.rb#24
  def darwin_app_list; end

  # source://launchy//lib/launchy/applications/browser.rb#28
  def nix_app_list; end

  # final assembly of the command and do %s substitution
  # http://www.catb.org/~esr/BROWSER/index.html
  #
  # source://launchy//lib/launchy/applications/browser.rb#77
  def open(uri, options = T.unsafe(nil)); end

  # source://launchy//lib/launchy/applications/browser.rb#15
  def windows_app_list; end

  class << self
    # @return [Boolean]
    #
    # source://launchy//lib/launchy/applications/browser.rb#10
    def handles?(uri); end

    # source://launchy//lib/launchy/applications/browser.rb#6
    def schemes; end
  end
end

# source://launchy//lib/launchy/error.rb#3
class Launchy::ApplicationNotFoundError < ::Launchy::Error; end

# source://launchy//lib/launchy/error.rb#5
class Launchy::ArgumentError < ::Launchy::Error; end

# source://launchy//lib/launchy/argv.rb#2
class Launchy::Argv
  # @return [Argv] a new instance of Argv
  #
  # source://launchy//lib/launchy/argv.rb#4
  def initialize(*args); end

  # source://launchy//lib/launchy/argv.rb#32
  def ==(other); end

  # source://launchy//lib/launchy/argv.rb#16
  def [](idx); end

  # Returns the value of attribute argv.
  #
  # source://launchy//lib/launchy/argv.rb#3
  def argv; end

  # @return [Boolean]
  #
  # source://launchy//lib/launchy/argv.rb#24
  def blank?; end

  # @return [Boolean]
  #
  # source://launchy//lib/launchy/argv.rb#28
  def executable?; end

  # source://launchy//lib/launchy/argv.rb#8
  def to_s; end

  # source://launchy//lib/launchy/argv.rb#12
  def to_str; end

  # @return [Boolean]
  #
  # source://launchy//lib/launchy/argv.rb#20
  def valid?; end
end

# This class is deprecated and will be removed
#
# source://launchy//lib/launchy/deprecated.rb#5
class Launchy::Browser
  # source://launchy//lib/launchy/deprecated.rb#10
  def visit(url); end

  private

  # source://launchy//lib/launchy/deprecated.rb#48
  def _warn(msg = T.unsafe(nil)); end

  # source://launchy//lib/launchy/deprecated.rb#19
  def find_caller_context(stack); end

  # source://launchy//lib/launchy/deprecated.rb#35
  def report_caller_context(stack); end

  class << self
    # source://launchy//lib/launchy/deprecated.rb#6
    def run(*args); end
  end
end

# source://launchy//lib/launchy/cli.rb#4
class Launchy::Cli
  # @return [Cli] a new instance of Cli
  #
  # source://launchy//lib/launchy/cli.rb#7
  def initialize; end

  # source://launchy//lib/launchy/cli.rb#75
  def error_output(error); end

  # source://launchy//lib/launchy/cli.rb#66
  def good_run(argv, env); end

  # Returns the value of attribute options.
  #
  # source://launchy//lib/launchy/cli.rb#6
  def options; end

  # source://launchy//lib/launchy/cli.rb#59
  def parse(argv, env); end

  # source://launchy//lib/launchy/cli.rb#11
  def parser; end

  # source://launchy//lib/launchy/cli.rb#85
  def run(argv = T.unsafe(nil), env = T.unsafe(nil)); end
end

# source://launchy//lib/launchy/error.rb#4
class Launchy::CommandNotFoundError < ::Launchy::Error; end

# Use by either
#
#   class Foo
#     extend DescendantTracker
#   end
#
# or
#
#   class Foo
#     class << self
#       include DescendantTracker
#     end
#   end
#
# It will track all the classes that inherit from the extended class and keep
# them in a Set that is available via the 'children' method.
#
# source://launchy//lib/launchy/descendant_tracker.rb#22
module Launchy::DescendantTracker
  # The list of children that are registered
  #
  # source://launchy//lib/launchy/descendant_tracker.rb#31
  def children; end

  # Find one of the child classes by calling the given method
  # and passing all the rest of the parameters to that method in
  # each child
  #
  # source://launchy//lib/launchy/descendant_tracker.rb#42
  def find_child(method, *args); end

  # source://launchy//lib/launchy/descendant_tracker.rb#23
  def inherited(klass); end
end

# source://launchy//lib/launchy/detect.rb#2
module Launchy::Detect; end

# source://launchy//lib/launchy/detect/host_os.rb#4
class Launchy::Detect::HostOs
  # @return [HostOs] a new instance of HostOs
  #
  # source://launchy//lib/launchy/detect/host_os.rb#10
  def initialize(host_os = T.unsafe(nil)); end

  # source://launchy//lib/launchy/detect/host_os.rb#22
  def default_host_os; end

  # Returns the value of attribute host_os.
  #
  # source://launchy//lib/launchy/detect/host_os.rb#6
  def host_os; end

  # source://launchy//lib/launchy/detect/host_os.rb#26
  def override_host_os; end

  # Returns the value of attribute host_os.
  #
  # source://launchy//lib/launchy/detect/host_os.rb#6
  def to_s; end

  # Returns the value of attribute host_os.
  #
  # source://launchy//lib/launchy/detect/host_os.rb#6
  def to_str; end
end

# Detect the current host os family
#
# If the current host familiy cannot be detected then return
# HostOsFamily::Unknown
#
# source://launchy//lib/launchy/detect/host_os_family.rb#6
class Launchy::Detect::HostOsFamily
  extend ::Launchy::DescendantTracker

  # @return [HostOsFamily] a new instance of HostOsFamily
  #
  # source://launchy//lib/launchy/detect/host_os_family.rb#30
  def initialize(host_os = T.unsafe(nil)); end

  # @return [Boolean]
  #
  # source://launchy//lib/launchy/detect/host_os_family.rb#37
  def cygwin?; end

  # @return [Boolean]
  #
  # source://launchy//lib/launchy/detect/host_os_family.rb#35
  def darwin?; end

  # Returns the value of attribute host_os.
  #
  # source://launchy//lib/launchy/detect/host_os_family.rb#29
  def host_os; end

  # @return [Boolean]
  #
  # source://launchy//lib/launchy/detect/host_os_family.rb#36
  def nix?; end

  # @return [Boolean]
  #
  # source://launchy//lib/launchy/detect/host_os_family.rb#34
  def windows?; end

  class << self
    # @return [Boolean]
    #
    # source://launchy//lib/launchy/detect/host_os_family.rb#25
    def cygwin?; end

    # @return [Boolean]
    #
    # source://launchy//lib/launchy/detect/host_os_family.rb#23
    def darwin?; end

    # @raise [NotFoundError]
    #
    # source://launchy//lib/launchy/detect/host_os_family.rb#12
    def detect(host_os = T.unsafe(nil)); end

    # @return [Boolean]
    #
    # source://launchy//lib/launchy/detect/host_os_family.rb#18
    def matches?(host_os); end

    # @return [Boolean]
    #
    # source://launchy//lib/launchy/detect/host_os_family.rb#24
    def nix?; end

    # @return [Boolean]
    #
    # source://launchy//lib/launchy/detect/host_os_family.rb#22
    def windows?; end
  end
end

# source://launchy//lib/launchy/detect/host_os_family.rb#64
class Launchy::Detect::HostOsFamily::Cygwin < ::Launchy::Detect::HostOsFamily
  # source://launchy//lib/launchy/detect/host_os_family.rb#68
  def app_list(app); end

  class << self
    # source://launchy//lib/launchy/detect/host_os_family.rb#65
    def matching_regex; end
  end
end

# source://launchy//lib/launchy/detect/host_os_family.rb#50
class Launchy::Detect::HostOsFamily::Darwin < ::Launchy::Detect::HostOsFamily
  # source://launchy//lib/launchy/detect/host_os_family.rb#54
  def app_list(app); end

  class << self
    # source://launchy//lib/launchy/detect/host_os_family.rb#51
    def matching_regex; end
  end
end

# source://launchy//lib/launchy/detect/host_os_family.rb#57
class Launchy::Detect::HostOsFamily::Nix < ::Launchy::Detect::HostOsFamily
  # source://launchy//lib/launchy/detect/host_os_family.rb#61
  def app_list(app); end

  class << self
    # source://launchy//lib/launchy/detect/host_os_family.rb#58
    def matching_regex; end
  end
end

# source://launchy//lib/launchy/detect/host_os_family.rb#7
class Launchy::Detect::HostOsFamily::NotFoundError < ::Launchy::Error; end

# ---------------------------
# All known host os families
# ---------------------------
#
# source://launchy//lib/launchy/detect/host_os_family.rb#43
class Launchy::Detect::HostOsFamily::Windows < ::Launchy::Detect::HostOsFamily
  # source://launchy//lib/launchy/detect/host_os_family.rb#47
  def app_list(app); end

  class << self
    # source://launchy//lib/launchy/detect/host_os_family.rb#44
    def matching_regex; end
  end
end

# Detect the current desktop environment for *nix machines
# Currently this is Linux centric. The detection is based upon the detection
# used by xdg-open from http://portland.freedesktop.org/
#
# source://launchy//lib/launchy/detect/nix_desktop_environment.rb#6
class Launchy::Detect::NixDesktopEnvironment
  extend ::Launchy::DescendantTracker

  class << self
    # source://launchy//lib/launchy/detect/nix_desktop_environment.rb#25
    def browsers; end

    # Detect the current *nix desktop environment
    #
    # If the current dekstop environment be detected, the return
    # NixDekstopEnvironment::Unknown
    #
    # source://launchy//lib/launchy/detect/nix_desktop_environment.rb#15
    def detect; end

    # source://launchy//lib/launchy/detect/nix_desktop_environment.rb#21
    def fallback_browsers; end
  end
end

# source://launchy//lib/launchy/detect/nix_desktop_environment.rb#44
class Launchy::Detect::NixDesktopEnvironment::Gnome < ::Launchy::Detect::NixDesktopEnvironment
  class << self
    # source://launchy//lib/launchy/detect/nix_desktop_environment.rb#50
    def browser; end

    # @return [Boolean]
    #
    # source://launchy//lib/launchy/detect/nix_desktop_environment.rb#45
    def is_current_desktop_environment?; end
  end
end

# ---------------------------------------
# The list of known desktop environments
# ---------------------------------------
#
# source://launchy//lib/launchy/detect/nix_desktop_environment.rb#33
class Launchy::Detect::NixDesktopEnvironment::Kde < ::Launchy::Detect::NixDesktopEnvironment
  class << self
    # source://launchy//lib/launchy/detect/nix_desktop_environment.rb#39
    def browser; end

    # @return [Boolean]
    #
    # source://launchy//lib/launchy/detect/nix_desktop_environment.rb#34
    def is_current_desktop_environment?; end
  end
end

# The one that is found when all else fails. And this must be declared last
#
# source://launchy//lib/launchy/detect/nix_desktop_environment.rb#81
class Launchy::Detect::NixDesktopEnvironment::NotFound < ::Launchy::Detect::NixDesktopEnvironment
  class << self
    # source://launchy//lib/launchy/detect/nix_desktop_environment.rb#86
    def browser; end

    # @return [Boolean]
    #
    # source://launchy//lib/launchy/detect/nix_desktop_environment.rb#82
    def is_current_desktop_environment?; end
  end
end

# source://launchy//lib/launchy/detect/nix_desktop_environment.rb#7
class Launchy::Detect::NixDesktopEnvironment::NotFoundError < ::Launchy::Error; end

# Fall back environment as the last case
#
# source://launchy//lib/launchy/detect/nix_desktop_environment.rb#70
class Launchy::Detect::NixDesktopEnvironment::Xdg < ::Launchy::Detect::NixDesktopEnvironment
  class << self
    # source://launchy//lib/launchy/detect/nix_desktop_environment.rb#75
    def browser; end

    # @return [Boolean]
    #
    # source://launchy//lib/launchy/detect/nix_desktop_environment.rb#71
    def is_current_desktop_environment?; end
  end
end

# source://launchy//lib/launchy/detect/nix_desktop_environment.rb#55
class Launchy::Detect::NixDesktopEnvironment::Xfce < ::Launchy::Detect::NixDesktopEnvironment
  class << self
    # source://launchy//lib/launchy/detect/nix_desktop_environment.rb#64
    def browser; end

    # @return [Boolean]
    #
    # source://launchy//lib/launchy/detect/nix_desktop_environment.rb#56
    def is_current_desktop_environment?; end
  end
end

# source://launchy//lib/launchy/detect/ruby_engine.rb#2
class Launchy::Detect::RubyEngine
  extend ::Launchy::DescendantTracker

  # @return [RubyEngine] a new instance of RubyEngine
  #
  # source://launchy//lib/launchy/detect/ruby_engine.rb#40
  def initialize(ruby_engine = T.unsafe(nil)); end

  # Returns the value of attribute ruby_engine.
  #
  # source://launchy//lib/launchy/detect/ruby_engine.rb#38
  def ruby_engine; end

  # Returns the value of attribute ruby_engine.
  #
  # source://launchy//lib/launchy/detect/ruby_engine.rb#38
  def to_s; end

  class << self
    # Detect the current ruby engine.
    #
    # If the current ruby engine cannot be detected, the return
    # RubyEngine::Unknown
    #
    # @raise [NotFoundError]
    #
    # source://launchy//lib/launchy/detect/ruby_engine.rb#11
    def detect(ruby_engine = T.unsafe(nil)); end

    # @return [Boolean]
    #
    # source://launchy//lib/launchy/detect/ruby_engine.rb#29
    def is_current_engine?(ruby_engine); end

    # @return [Boolean]
    #
    # source://launchy//lib/launchy/detect/ruby_engine.rb#34
    def jruby?; end

    # @return [Boolean]
    #
    # source://launchy//lib/launchy/detect/ruby_engine.rb#36
    def macruby?; end

    # @return [Boolean]
    #
    # source://launchy//lib/launchy/detect/ruby_engine.rb#33
    def mri?; end

    # @return [Boolean]
    #
    # source://launchy//lib/launchy/detect/ruby_engine.rb#35
    def rbx?; end

    # source://launchy//lib/launchy/detect/ruby_engine.rb#17
    def ruby_engine_error_message(ruby_engine); end
  end
end

# source://launchy//lib/launchy/detect/ruby_engine.rb#66
class Launchy::Detect::RubyEngine::Jruby < ::Launchy::Detect::RubyEngine
  class << self
    # source://launchy//lib/launchy/detect/ruby_engine.rb#67
    def engine_name; end
  end
end

# source://launchy//lib/launchy/detect/ruby_engine.rb#74
class Launchy::Detect::RubyEngine::MacRuby < ::Launchy::Detect::RubyEngine
  class << self
    # source://launchy//lib/launchy/detect/ruby_engine.rb#75
    def engine_name; end
  end
end

# This is the ruby engine if the RUBY_ENGINE constant is not defined
#
# source://launchy//lib/launchy/detect/ruby_engine.rb#55
class Launchy::Detect::RubyEngine::Mri < ::Launchy::Detect::RubyEngine
  class << self
    # source://launchy//lib/launchy/detect/ruby_engine.rb#56
    def engine_name; end

    # @return [Boolean]
    #
    # source://launchy//lib/launchy/detect/ruby_engine.rb#57
    def is_current_engine?(ruby_engine); end
  end
end

# source://launchy//lib/launchy/detect/ruby_engine.rb#3
class Launchy::Detect::RubyEngine::NotFoundError < ::Launchy::Error; end

# source://launchy//lib/launchy/detect/ruby_engine.rb#70
class Launchy::Detect::RubyEngine::Rbx < ::Launchy::Detect::RubyEngine
  class << self
    # source://launchy//lib/launchy/detect/ruby_engine.rb#71
    def engine_name; end
  end
end

# source://launchy//lib/launchy/detect/runner.rb#5
class Launchy::Detect::Runner
  extend ::Launchy::DescendantTracker

  # source://launchy//lib/launchy/detect/runner.rb#46
  def commandline_normalize(cmdline); end

  # source://launchy//lib/launchy/detect/runner.rb#53
  def dry_run(cmd, *args); end

  # @raise [Launchy::CommandNotFoundError]
  #
  # source://launchy//lib/launchy/detect/runner.rb#57
  def run(cmd, *args); end

  # cut it down to just the shell commands that will be passed to exec or
  # posix_spawn. The cmd argument is split according to shell rules and the
  # args are not escaped because they whole set is passed to system as *args
  # and in that case system shell escaping rules are not done.
  #
  # source://launchy//lib/launchy/detect/runner.rb#40
  def shell_commands(cmd, args); end

  class << self
    # Detect the current command runner
    #
    # This will return an instance of the Runner to be used to do the
    # application launching.
    #
    # If a runner cannot be detected then raise Runner::NotFoundError
    #
    # The runner rules are, in order:
    #
    # 1) If you are on windows, you use the Windows Runner no matter what
    # 2) If you are using the jruby engine, use the Jruby Runner. Unless rule
    #    (1) took effect
    # 3) Use Forkable (barring rules (1) and (2))
    #
    # source://launchy//lib/launchy/detect/runner.rb#23
    def detect; end
  end
end

# source://launchy//lib/launchy/detect/runner.rb#116
class Launchy::Detect::Runner::Forkable < ::Launchy::Detect::Runner
  # Returns the value of attribute child_pid.
  #
  # source://launchy//lib/launchy/detect/runner.rb#117
  def child_pid; end

  # source://launchy//lib/launchy/detect/runner.rb#119
  def wet_run(cmd, *args); end

  private

  # attaching to a StringIO instead of reopening so we don't loose the
  # STDERR, needed for exec_or_raise.
  #
  # source://launchy//lib/launchy/detect/runner.rb#133
  def close_file_descriptors; end

  # source://launchy//lib/launchy/detect/runner.rb#143
  def exec_or_raise(cmd, *args); end
end

# source://launchy//lib/launchy/detect/runner.rb#109
class Launchy::Detect::Runner::Jruby < ::Launchy::Detect::Runner
  # source://launchy//lib/launchy/detect/runner.rb#110
  def wet_run(cmd, *args); end
end

# source://launchy//lib/launchy/detect/runner.rb#6
class Launchy::Detect::Runner::NotFoundError < ::Launchy::Error; end

# ---------------------------------------
# The list of known runners
# ---------------------------------------
#
# source://launchy//lib/launchy/detect/runner.rb#71
class Launchy::Detect::Runner::Windows < ::Launchy::Detect::Runner
  # source://launchy//lib/launchy/detect/runner.rb#73
  def all_args(cmd, *args); end

  # source://launchy//lib/launchy/detect/runner.rb#79
  def dry_run(cmd, *args); end

  # escape the reserved shell characters in windows command shell
  # http://technet.microsoft.com/en-us/library/cc723564.aspx
  #
  # Also make sure that the item after 'start' is guaranteed to be quoted.
  # https://github.com/copiousfreetime/launchy/issues/62
  #
  # source://launchy//lib/launchy/detect/runner.rb#88
  def shell_commands(cmd, *args); end

  # source://launchy//lib/launchy/detect/runner.rb#104
  def wet_run(cmd, *args); end
end

# source://launchy//lib/launchy/error.rb#2
class Launchy::Error < ::StandardError; end

# source://launchy//lib/launchy/version.rb#2
Launchy::VERSION = T.let(T.unsafe(nil), String)

# source://launchy//lib/launchy/version.rb#4
module Launchy::Version
  class << self
    # source://launchy//lib/launchy/version.rb#10
    def to_a; end

    # source://launchy//lib/launchy/version.rb#14
    def to_s; end
  end
end

# source://launchy//lib/launchy/version.rb#6
Launchy::Version::MAJOR = T.let(T.unsafe(nil), Integer)

# source://launchy//lib/launchy/version.rb#7
Launchy::Version::MINOR = T.let(T.unsafe(nil), Integer)

# source://launchy//lib/launchy/version.rb#8
Launchy::Version::PATCH = T.let(T.unsafe(nil), Integer)
