module RefinedString
  refine String do
    def encode
      cipher = OpenSSL::Cipher.new("AES-128-ECB").encrypt
      cipher.key =
        OpenSSL::PKCS5
          .pbkdf2_hmac_sha1("ENCODE_PASS", "ENCODE_SALT", 1, cipher.key_len)

      encrypted = cipher.update(to_s) + cipher.final
      encrypted.unpack1("H*")&.upcase
    end

    def decode
      cipher = OpenSSL::Cipher.new("AES-128-ECB").decrypt
      cipher.key =
        OpenSSL::PKCS5
          .pbkdf2_hmac_sha1("ENCODE_PASS", "ENCODE_SALT", 1, cipher.key_len)

      decrypted = [self].pack("H*").unpack("C*").pack("c*")
      cipher.update(decrypted) + cipher.final
    end

    def time
      Time.parse(self)
    end

    def in_tz(tz)
      time.in_time_zone(tz)
    end
  end
end
