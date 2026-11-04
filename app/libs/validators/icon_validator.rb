module Validators
  class IconValidator
    ICON_ALLOWED_CONTENT_TYPES = %w[image/png image/jpeg image/webp image/jpg].freeze
    ICON_FILE_SIZE_LIMIT = 1.megabyte
    ICON_ALLOWED_DIMENSIONS = [512, 1024].freeze

    def self.validate(icon_file)
      new(icon_file).validate
    end

    attr_reader :errors

    def initialize(icon_file)
      @icon_file = icon_file
      @errors = []
    end

    def validate
      return self if icon_file.nil?

      unless icon_file.content_type.in?(ICON_ALLOWED_CONTENT_TYPES)
        errors << "the file format is not supported."
        return self
      end

      maximum_file_size
      square_shape_and_dimensions
      self
    end

    private

    attr_reader :icon_file

    def maximum_file_size
      if icon_file.size > ICON_FILE_SIZE_LIMIT
        errors << "the icon is too large, it must be smaller than #{ICON_FILE_SIZE_LIMIT} bytes."
      end
    end

    def square_shape_and_dimensions
      image = Vips::Image.new_from_file(icon_file.path)
      width = image.width
      height = image.height
      if width != height
        errors << "the icon must be a square image."
      end
      unless width.in?(ICON_ALLOWED_DIMENSIONS)
        errors << "the icon size must either be #{ICON_ALLOWED_DIMENSIONS.first}x#{ICON_ALLOWED_DIMENSIONS.first} or #{ICON_ALLOWED_DIMENSIONS.last}x#{ICON_ALLOWED_DIMENSIONS.last} pixels."
      end
    end
  end
end
