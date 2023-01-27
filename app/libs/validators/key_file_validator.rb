module Validators
  class KeyFileValidator
    KEY_FILE_SIZE_LIMIT = 4096

    def self.validate(key_file)
      new(key_file).validate
    end

    attr_reader :errors

    def initialize(key_file)
      @key_file = key_file
      @errors = []
    end

    def validate
      if key_file.nil?
        errors << "please select a valid key file!"
        return self
      end

      maximum_file_size
      self
    end

    private

    attr_reader :key_file

    def maximum_file_size
      if key_file.size > KEY_FILE_SIZE_LIMIT
        errors << "the key file is too large, it must be smaller than #{KEY_FILE_SIZE_LIMIT} bytes."
      end
    end
  end
end
