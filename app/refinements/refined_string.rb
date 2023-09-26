module RefinedString
  refine String do
    def encode
      ActiveSupport::MessageEncryptor
        .new(Rails.application.secret_key_base[0..31])
        .encrypt_and_sign(self)
    end

    def decode
      ActiveSupport::MessageEncryptor
        .new(Rails.application.secret_key_base[0..31])
        .decrypt_and_verify(self)
    end

    def to_boolean
      ActiveModel::Type::Boolean.new.cast(self)
    end

    def in_tz(tz)
      ActiveSupport::TimeZone.new(tz).parse(self)
    rescue NoMethodError
      Time.zone.parse(self)
    end

    def time_in_utc
      return if blank?
      Time.zone.parse(self).utc
    end

    def safe_float
      Float(self)
    rescue ArgumentError, TypeError
      0.0
    end

    def safe_integer
      Integer(self)
    rescue ArgumentError, TypeError
      0
    end

    def safe_json_parse
      JSON.parse(self)
    rescue JSON::ParserError
      {}
    end

    def safe_csv_parse
      split(",").reject(&:empty?).map { |v| Float(v) }
    rescue ArgumentError
      []
    end

    def to_semverish
      VersioningStrategies::Semverish.new(to_s)
    end

    def ver_bump(term)
      to_semverish.bump!(term).to_s
    end

    def better_titleize
      words = split(" ")
      words.map! do |word|
        if word == word.upcase
          word
        else
          word.capitalize
        end
      end
      words.join(" ")
    end

    def break_into_chunks(max_length)
      chunks = []
      current_chunk = ""

      each_line do |line|
        if current_chunk.length + line.length <= max_length
          current_chunk << line
        else
          chunks << current_chunk
          current_chunk = line
        end
      end

      chunks << current_chunk unless current_chunk.empty?
      chunks
    end
  end
end
