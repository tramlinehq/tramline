require "zip"

module Artifacts
  class Stream
    VALID_UNZIPS = "*.{aab,apk,txt,ipa}".freeze
    ARCHIVE_REGEX = /^\x50\x4b\x03\x04/
    AAB_FILE_TYPE = ".aab".freeze
    APK_FILE_TYPE = ".apk".freeze
    IPA_FILE_TYPE = ".ipa".freeze

    class SingleUnzipSupportedOnly < StandardError; end

    StreamIO = Struct.new(:file, :ext)

    def initialize(tempfile, is_archive: false)
      @tempfile = tempfile
      @is_archive = is_archive
    end

    def with_open(&)
      if unzip?
        open_zip(&)
      else
        yield(StreamIO.new(tempfile, extname(tempfile)))
      end
    end

    def open_zip(&_blk)
      unzip.each do |entry|
        basename = File.basename(entry.name)
        ext = extname(entry.name)
        extract_file = Tempfile.new([basename, ext])
        begin
          entry.extract(extract_file) { true }
          yield(StreamIO.new(extract_file, ext))
        ensure
          extract_file.close(true)
        end
      end
    end

    def unzip
      entries = Zip::File.open(tempfile).glob(VALID_UNZIPS)
      raise SingleUnzipSupportedOnly if entries.size > 1
      entries
    end

    attr_reader :tempfile

    def unzip?
      @is_archive
    end

    def extname(file)
      ext = File.extname(file)
      ext = detect_file_type(file) if ext.blank?
      ext
    end

    def detect_file_type(file)
      header_hex = ::File.read(file, 100)
      return detect_archive_file(file) if header_hex.match?(ARCHIVE_REGEX)
      ""
    end

    def detect_archive_file(file)
      Zip.warn_invalid_date = false
      archive = Zip::File.open(file)
      return APK_FILE_TYPE if apk_clues?(archive)
      return AAB_FILE_TYPE if aab_clues?(archive)
      return IPA_FILE_TYPE if ipa_clues?(archive)
      ""
    ensure
      archive&.close
    end

    def apk_clues?(archive)
      !archive.find_entry("AndroidManifest.xml").nil? && !archive.find_entry("classes.dex").nil?
    end

    def aab_clues?(archive)
      !archive.find_entry("base/manifest/AndroidManifest.xml").nil? && !archive.find_entry("BundleConfig.pb").nil?
    end

    def ipa_clues?(archive)
      archive.each do |f|
        path = f.name
        path.include?("Payload/") && path.end_with?("Info.plist")
      end
    end
  end
end
