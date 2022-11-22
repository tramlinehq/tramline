module Validators
  module GooglePlayStore
    class JsonKeyValidator
      JSON_KEY_FILE_SIZE_LIMIT = 4096

      def self.validate(json_key_file)
        new(json_key_file).validate
      end

      attr_reader :errors

      def initialize(json_key_file)
        @json_key_file = json_key_file
        @errors = []
      end

      def validate
        if json_key_file.nil?
          errors << "please select a valid JSON key file!"
          return self
        end

        maximum_file_size
        self
      end

      private

      attr_reader :json_key_file

      def maximum_file_size
        if json_key_file.size > JSON_KEY_FILE_SIZE_LIMIT
          errors << "JSON key file is too large, it must be smaller than #{JSON_KEY_FILE_SIZE_LIMIT} bytes."
        end
      end
    end
  end
end
