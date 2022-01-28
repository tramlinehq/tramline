module StringUtils
  SIMPLE_ENCRYPTION_PASS = Rails.application.credentials.simple_encryption.pass
  SIMPLE_ENCRYPTION_SALT = Rails.application.credentials.simple_encryption.salt
  SIMPLE_ENCRYPTION_ITERS = 20
  SIMPLE_ENCRYPTION_CIPHER = "AES-128-ECB"
  private_constant :SIMPLE_ENCRYPTION_PASS
  private_constant :SIMPLE_ENCRYPTION_SALT
  private_constant :SIMPLE_ENCRYPTION_ITERS
  private_constant :SIMPLE_ENCRYPTION_CIPHER

  refine String do
    def encrypt
      cipher = OpenSSL::Cipher.new(SIMPLE_ENCRYPTION_CIPHER).encrypt
      cipher.key =
        OpenSSL::PKCS5
          .pbkdf2_hmac_sha1(SIMPLE_ENCRYPTION_PASS, SIMPLE_ENCRYPTION_SALT, SIMPLE_ENCRYPTION_ITERS, cipher.key_len)
      encrypted = cipher.update(to_s) + cipher.final

      encrypted.unpack1("H*")&.upcase
    end

    def decrypt
      cipher = OpenSSL::Cipher.new(SIMPLE_ENCRYPTION_CIPHER).decrypt
      cipher.key =
        OpenSSL::PKCS5
          .pbkdf2_hmac_sha1(SIMPLE_ENCRYPTION_PASS, SIMPLE_ENCRYPTION_SALT, SIMPLE_ENCRYPTION_ITERS, cipher.key_len)
      decrypted = [self].pack("H*").unpack("C*").pack("c*")

      cipher.update(decrypted) + cipher.final
    end
  end
end
