# typed: true

# DO NOT EDIT MANUALLY
# This is an autogenerated file for types exported from the `ruby-duration` gem.
# Please instead update this file by running `bin/tapioca gem ruby-duration`.


# Duration objects are simple mechanisms that allow you to operate on durations
# of time.  They allow you to know how much time has passed since a certain
# point in time, or they can tell you how much time something is (when given as
# seconds) in different units of time measurement.  Durations would particularly
# be useful for those scripts or applications that allow you to know the uptime
# of themselves or perhaps provide a countdown until a certain event.
#
# source://ruby-duration//lib/duration.rb#12
class Duration
  include ::Comparable

  # Initialize a duration. 'args' can be a hash or anything else.  If a hash is
  # passed, it will be scanned for a key=>value pair of time units such as those
  # listed in the Duration::UNITS array or Duration::MULTIPLES hash.
  #
  # If anything else except a hash is passed, #to_i is invoked on that object
  # and expects that it return the number of seconds desired for the duration.
  #
  # @return [Duration] a new instance of Duration
  #
  # source://ruby-duration//lib/duration.rb#36
  def initialize(args = T.unsafe(nil)); end

  # source://ruby-duration//lib/duration.rb#82
  def %(other); end

  # source://ruby-duration//lib/duration.rb#74
  def *(other); end

  # source://ruby-duration//lib/duration.rb#66
  def +(other); end

  # source://ruby-duration//lib/duration.rb#70
  def -(other); end

  # source://ruby-duration//lib/duration.rb#78
  def /(other); end

  # Compare this duration to another (or objects that respond to #to_i)
  #
  # source://ruby-duration//lib/duration.rb#61
  def <=>(other); end

  # @return [Boolean] true if total is 0
  #
  # source://ruby-duration//lib/duration.rb#112
  def blank?; end

  # Returns the value of attribute days.
  #
  # source://ruby-duration//lib/duration.rb#28
  def days; end

  # Format a duration into a human-readable string.
  #
  #   %w   => weeks
  #   %d   => days
  #   %h   => hours
  #   %m   => minutes
  #   %s   => seconds
  #   %td  => total days
  #   %th  => total hours
  #   %tm  => total minutes
  #   %ts  => total seconds
  #   %t   => total seconds
  #   %MP  => minutes with UTF-8 prime
  #   %SP  => seconds with UTF-8 double-prime
  #   %MH  => minutes with HTML prime
  #   %SH  => seconds with HTML double-prime
  #   %H   => zero-padded hours
  #   %M   => zero-padded minutes
  #   %S   => zero-padded seconds
  #   %~s  => locale-dependent "seconds" terminology
  #   %~m  => locale-dependent "minutes" terminology
  #   %~h  => locale-dependent "hours" terminology
  #   %~d  => locale-dependent "days" terminology
  #   %~w  => locale-dependent "weeks" terminology
  #   %tdu => total days with locale-dependent unit
  #   %thu => total hours with locale-dependent unit
  #   %tmu => total minutes with locale-dependent unit
  #   %tsu => total seconds with locale-dependent unit
  #
  # You can also use the I18n support.
  # The %~s, %~m, %~h, %~d and %~w can be translated with I18n.
  # If you are using Ruby on Rails, the support is ready out of the box, so just change your locale file. Otherwise you can try:
  #
  #   I18n.load_path << "path/to/your/locale"
  #   I18n.locale = :your_locale
  #
  # And you must use the following structure (example) for your locale file:
  #   pt:
  #     ruby_duration:
  #       second: segundo
  #       seconds: segundos
  #       minute: minuto
  #       minutes: minutos
  #       hour: hora
  #       hours: horas
  #       day: dia
  #       days: dias
  #       week: semana
  #       weeks: semanas
  #
  # source://ruby-duration//lib/duration.rb#175
  def format(format_str); end

  # Returns the value of attribute hours.
  #
  # source://ruby-duration//lib/duration.rb#28
  def hours; end

  # Formats a duration in ISO8601.
  #
  # @see http://en.wikipedia.org/wiki/ISO_8601#Durations
  #
  # source://ruby-duration//lib/duration.rb#92
  def iso8601; end

  # Returns the value of attribute minutes.
  #
  # source://ruby-duration//lib/duration.rb#28
  def minutes; end

  # @return [Boolean]
  #
  # source://ruby-duration//lib/duration.rb#121
  def negative?; end

  # @return [Boolean] true if total different than 0
  #
  # source://ruby-duration//lib/duration.rb#117
  def present?; end

  # Returns the value of attribute seconds.
  #
  # source://ruby-duration//lib/duration.rb#28
  def seconds; end

  # Format a duration into a human-readable string.
  #
  #   %w   => weeks
  #   %d   => days
  #   %h   => hours
  #   %m   => minutes
  #   %s   => seconds
  #   %td  => total days
  #   %th  => total hours
  #   %tm  => total minutes
  #   %ts  => total seconds
  #   %t   => total seconds
  #   %MP  => minutes with UTF-8 prime
  #   %SP  => seconds with UTF-8 double-prime
  #   %MH  => minutes with HTML prime
  #   %SH  => seconds with HTML double-prime
  #   %H   => zero-padded hours
  #   %M   => zero-padded minutes
  #   %S   => zero-padded seconds
  #   %~s  => locale-dependent "seconds" terminology
  #   %~m  => locale-dependent "minutes" terminology
  #   %~h  => locale-dependent "hours" terminology
  #   %~d  => locale-dependent "days" terminology
  #   %~w  => locale-dependent "weeks" terminology
  #   %tdu => total days with locale-dependent unit
  #   %thu => total hours with locale-dependent unit
  #   %tmu => total minutes with locale-dependent unit
  #   %tsu => total seconds with locale-dependent unit
  #
  # You can also use the I18n support.
  # The %~s, %~m, %~h, %~d and %~w can be translated with I18n.
  # If you are using Ruby on Rails, the support is ready out of the box, so just change your locale file. Otherwise you can try:
  #
  #   I18n.load_path << "path/to/your/locale"
  #   I18n.locale = :your_locale
  #
  # And you must use the following structure (example) for your locale file:
  #   pt:
  #     ruby_duration:
  #       second: segundo
  #       seconds: segundos
  #       minute: minuto
  #       minutes: minutos
  #       hour: hora
  #       hours: horas
  #       day: dia
  #       days: dias
  #       week: semana
  #       weeks: semanas
  #
  # source://ruby-duration//lib/duration.rb#175
  def strftime(format_str); end

  # Returns the value of attribute total.
  #
  # source://ruby-duration//lib/duration.rb#28
  def to_i; end

  # Returns the value of attribute total.
  #
  # source://ruby-duration//lib/duration.rb#28
  def total; end

  # source://ruby-duration//lib/duration.rb#87
  def total_days; end

  # source://ruby-duration//lib/duration.rb#87
  def total_hours; end

  # source://ruby-duration//lib/duration.rb#87
  def total_minutes; end

  # Returns the value of attribute weeks.
  #
  # source://ruby-duration//lib/duration.rb#28
  def weeks; end

  private

  # Calculates the duration from seconds and figures out what the actual
  # durations are in specific units.  This method is called internally, and
  # does not need to be called by user code.
  #
  # source://ruby-duration//lib/duration.rb#218
  def calculate!; end

  # source://ruby-duration//lib/duration.rb#233
  def i18n_for(singular); end

  class << self
    # source://ruby-duration//lib/duration.rb#56
    def dump(duration); end

    # source://ruby-duration//lib/duration.rb#52
    def load(string); end
  end
end

# source://ruby-duration//lib/duration.rb#17
Duration::MULTIPLES = T.let(T.unsafe(nil), Hash)

# source://ruby-duration//lib/duration.rb#15
Duration::UNITS = T.let(T.unsafe(nil), Array)
