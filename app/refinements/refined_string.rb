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
  end
end
