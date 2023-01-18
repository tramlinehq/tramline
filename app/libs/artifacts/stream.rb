require "zip"

module Artifacts
  class Stream
    VALID_UNZIPS = "*.{aab,apk,txt}".freeze

    class SingleUnzipSupportedOnly < StandardError; end

    StreamIO = Struct.new(:file, :ext)

    def initialize(tempfile, is_archive: false)
      @tempfile = tempfile
      @is_archive = is_archive
    end

    def with_open(&blk)
      if unzip?
        open_zip(&blk)
      else
        yield(StreamIO.new(tempfile, File.extname(tempfile)))
      end
    end

    private

    def open_zip(&_blk)
      unzip.each do |entry|
        basename = File.basename(entry.name)
        ext = File.extname(entry.name)
        Tempfile.open([basename, ext]) do |extract_file|
          entry.extract(extract_file) { true }
          yield(StreamIO.new(extract_file, ext))
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
  end
end
