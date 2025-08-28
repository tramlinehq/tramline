module Validators
  class AppIconValidator
    APP_ICON_FILE_SIZE_LIMIT = 1.megabyte
    MIN_DIMENSION = 512
    MAX_DIMENSION = 1024

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
      unless width.in?(MIN_DIMENSION..MAX_DIMENSION)
        errors << "the app icon size must be at least #{MIN_DIMENSION}x#{MIN_DIMENSION} pixels and at most #{MAX_DIMENSION}x#{MAX_DIMENSION} pixels."
      end
    end
  end
end
