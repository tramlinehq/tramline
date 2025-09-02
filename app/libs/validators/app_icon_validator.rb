module Validators
  class AppIconValidator
    APP_ICON_ALLOWED_CONTENT_TYPES = %w[image/png image/jpeg image/webp image/jpg].freeze
    APP_ICON_FILE_SIZE_LIMIT = 1.megabyte
    APP_ICON_ALLOWED_DIMENSIONS = [512, 1024].freeze

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

      unless icon_file.content_type.in?(APP_ICON_ALLOWED_CONTENT_TYPES)
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
      if icon_file.size > APP_ICON_FILE_SIZE_LIMIT
        errors << "the app icon is too large, it must be smaller than #{APP_ICON_FILE_SIZE_LIMIT} bytes."
      end
    end

    def square_shape_and_dimensions
      image = Vips::Image.new_from_file(icon_file.path)
      width = image.width
      height = image.height
      if width != height
        errors << "the app icon must be a square image."
      end
      unless width.in?(APP_ICON_ALLOWED_DIMENSIONS)
        errors << "the app icon size must either be #{APP_ICON_ALLOWED_DIMENSIONS.first}x#{APP_ICON_ALLOWED_DIMENSIONS.first} or #{APP_ICON_ALLOWED_DIMENSIONS.last}x#{APP_ICON_ALLOWED_DIMENSIONS.last} pixels."
      end
    end
  end
end
