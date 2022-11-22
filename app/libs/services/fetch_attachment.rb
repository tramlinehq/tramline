class Services::FetchAttachment
  SIZE_LIMIT = 4096
  JSON_CONTENT_TYPE = "application/json"

  class InvalidAttachment < StandardError; end

  def self.for_json(file)
    new(file, JSON_CONTENT_TYPE).parse
  end

  def initialize(file, content_type, size_limit = SIZE_LIMIT)
    @file = file
    @size_limit = size_limit
    @content_type = content_type
  end

  def parse
    raise InvalidAttachment, "please upload a valid JSON file!" unless valid?
    read
  end

  private

  attr_reader :file, :size_limit, :content_type

  def read
    return @content if @content.present?
    file.rewind # TODO: revisit this, why do we need to rewind?
    @content = file.read
  end

  def valid?
    !file.nil? && valid_size? && valid_file?
  end

  def valid_size?
    file.size < size_limit
  end

  def valid_file?
    case content_type
    when JSON_CONTENT_TYPE
      begin
        JSON.parse(read)
      rescue JSON::ParserError
        false
      end
    else
      false
    end
  end
end
