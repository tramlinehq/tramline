module StringUtils
  SIMPLE_ENCRYPTION_PASS = Rails.application.credentials.simple_encryption.pass
  SIMPLE_ENCRYPTION_SALT = Rails.application.credentials.simple_encryption.salt
  private_constant :SIMPLE_ENCRYPTION_PASS
  private_constant :SIMPLE_ENCRYPTION_SALT

  refine String do
    def encrypt
      cipher = OpenSSL::Cipher.new("AES-128-ECB").encrypt
      cipher.key =
        OpenSSL::PKCS5
          .pbkdf2_hmac_sha1(SIMPLE_ENCRYPTION_PASS, SIMPLE_ENCRYPTION_SALT, 20_000, cipher.key_len)
      encrypted = cipher.update(to_s) + cipher.final

      encrypted.unpack1("H*")&.upcase
    end

    def decrypt
      cipher = OpenSSL::Cipher.new("AES-128-ECB").decrypt
      cipher.key =
        OpenSSL::PKCS5
          .pbkdf2_hmac_sha1(SIMPLE_ENCRYPTION_PASS, SIMPLE_ENCRYPTION_SALT, 20_000, cipher.key_len)
      decrypted = [self].pack("H*").unpack("C*").pack("c*")

      cipher.update(decrypted) + cipher.final
    end
  end
end
