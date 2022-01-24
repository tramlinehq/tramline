module StringUtils
  INTERNAL_ENCRYPTION_PASS = "some-random-salt-"
  INTERNAL_ENCRYPTION_SALT = "another-random-salt-"

  refine String do
    def encrypt
      cipher = OpenSSL::Cipher.new("AES-128-ECB").encrypt
      cipher.key =
        OpenSSL::PKCS5
          .pbkdf2_hmac_sha1(INTERNAL_ENCRYPTION_PASS, INTERNAL_ENCRYPTION_SALT, 20_000, cipher.key_len)
      encrypted = cipher.update(to_s) + cipher.final
      encrypted.unpack1("H*")&.upcase
    end

    def decrypt
      cipher = OpenSSL::Cipher.new("AES-128-ECB").decrypt
      cipher.key =
        OpenSSL::PKCS5
          .pbkdf2_hmac_sha1(INTERNAL_ENCRYPTION_PASS, INTERNAL_ENCRYPTION_SALT, 20_000, cipher.key_len)
      decrypted = [self].pack("H*").unpack("C*").pack("c*")

      cipher.update(decrypted) + cipher.final
    end
  end
end
