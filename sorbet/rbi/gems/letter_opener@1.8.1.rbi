# typed: true

# DO NOT EDIT MANUALLY
# This is an autogenerated file for types exported from the `letter_opener` gem.
# Please instead update this file by running `bin/tapioca gem letter_opener`.


# source://letter_opener//lib/letter_opener.rb#1
module LetterOpener
  class << self
    # source://letter_opener//lib/letter_opener.rb#6
    def configuration; end

    # @yield [configuration]
    #
    # source://letter_opener//lib/letter_opener.rb#10
    def configure; end
  end
end

# source://letter_opener//lib/letter_opener/configuration.rb#2
class LetterOpener::Configuration
  # @return [Configuration] a new instance of Configuration
  #
  # source://letter_opener//lib/letter_opener/configuration.rb#5
  def initialize; end

  # Returns the value of attribute file_uri_scheme.
  #
  # source://letter_opener//lib/letter_opener/configuration.rb#3
  def file_uri_scheme; end

  # Sets the attribute file_uri_scheme
  #
  # @param value the value to set the attribute file_uri_scheme to.
  #
  # source://letter_opener//lib/letter_opener/configuration.rb#3
  def file_uri_scheme=(_arg0); end

  # Returns the value of attribute location.
  #
  # source://letter_opener//lib/letter_opener/configuration.rb#3
  def location; end

  # Sets the attribute location
  #
  # @param value the value to set the attribute location to.
  #
  # source://letter_opener//lib/letter_opener/configuration.rb#3
  def location=(_arg0); end

  # Returns the value of attribute message_template.
  #
  # source://letter_opener//lib/letter_opener/configuration.rb#3
  def message_template; end

  # Sets the attribute message_template
  #
  # @param value the value to set the attribute message_template to.
  #
  # source://letter_opener//lib/letter_opener/configuration.rb#3
  def message_template=(_arg0); end
end

# source://letter_opener//lib/letter_opener/delivery_method.rb#5
class LetterOpener::DeliveryMethod
  # @raise [InvalidOption]
  # @return [DeliveryMethod] a new instance of DeliveryMethod
  #
  # source://letter_opener//lib/letter_opener/delivery_method.rb#10
  def initialize(options = T.unsafe(nil)); end

  # source://letter_opener//lib/letter_opener/delivery_method.rb#20
  def deliver!(mail); end

  # Returns the value of attribute settings.
  #
  # source://letter_opener//lib/letter_opener/delivery_method.rb#8
  def settings; end

  # Sets the attribute settings
  #
  # @param value the value to set the attribute settings to.
  #
  # source://letter_opener//lib/letter_opener/delivery_method.rb#8
  def settings=(_arg0); end

  private

  # source://letter_opener//lib/letter_opener/delivery_method.rb#30
  def validate_mail!(mail); end
end

# source://letter_opener//lib/letter_opener/delivery_method.rb#6
class LetterOpener::DeliveryMethod::InvalidOption < ::StandardError; end

# source://letter_opener//lib/letter_opener/message.rb#8
class LetterOpener::Message
  # @raise [ArgumentError]
  # @return [Message] a new instance of Message
  #
  # source://letter_opener//lib/letter_opener/message.rb#22
  def initialize(mail, options = T.unsafe(nil)); end

  # source://letter_opener//lib/letter_opener/message.rb#133
  def <=>(other); end

  # source://letter_opener//lib/letter_opener/message.rb#126
  def attachment_filename(attachment); end

  # source://letter_opener//lib/letter_opener/message.rb#116
  def auto_link(text); end

  # source://letter_opener//lib/letter_opener/message.rb#100
  def bcc; end

  # source://letter_opener//lib/letter_opener/message.rb#68
  def body; end

  # source://letter_opener//lib/letter_opener/message.rb#96
  def cc; end

  # source://letter_opener//lib/letter_opener/message.rb#64
  def content_type; end

  # source://letter_opener//lib/letter_opener/message.rb#112
  def encoding; end

  # source://letter_opener//lib/letter_opener/message.rb#60
  def filepath; end

  # source://letter_opener//lib/letter_opener/message.rb#80
  def from; end

  # source://letter_opener//lib/letter_opener/message.rb#122
  def h(content); end

  # Returns the value of attribute mail.
  #
  # source://letter_opener//lib/letter_opener/message.rb#9
  def mail; end

  # source://letter_opener//lib/letter_opener/message.rb#33
  def render; end

  # source://letter_opener//lib/letter_opener/message.rb#104
  def reply_to; end

  # source://letter_opener//lib/letter_opener/message.rb#84
  def sender; end

  # source://letter_opener//lib/letter_opener/message.rb#88
  def subject; end

  # source://letter_opener//lib/letter_opener/message.rb#56
  def template; end

  # source://letter_opener//lib/letter_opener/message.rb#92
  def to; end

  # source://letter_opener//lib/letter_opener/message.rb#108
  def type; end

  class << self
    # source://letter_opener//lib/letter_opener/message.rb#11
    def rendered_messages(mail, options = T.unsafe(nil)); end
  end
end

# source://letter_opener//lib/letter_opener/message.rb#20
LetterOpener::Message::ERROR_MSG = T.let(T.unsafe(nil), String)

# source://letter_opener//lib/letter_opener/railtie.rb#2
class LetterOpener::Railtie < ::Rails::Railtie; end
