require "zip"

class DownloadStream
  VALID_UNZIPS = "*.{aab,apk,txt}".freeze

  class SingleUnzipSupportedOnly < StandardError; end

  DownloadStreamIO = Struct.new(:file, :ext)

  def initialize(tempfile, is_unzip = false)
    @tempfile = tempfile
    @is_unzip = is_unzip
  end

  def with_open(&blk)
    if unzip?
      open_zip(&blk)
    else
      yield(DownloadStreamIO.new(tempfile, File.extname(tempfile)))
    end
  end

  private

  def open_zip(&blk)
    unzip.each do |entry|
      basename = File.basename(entry.name)
      ext = File.extname(entry.name)
      Tempfile.open([basename, ext]) do |extract_file|
        entry.extract(extract_file) { true }
        yield(DownloadStreamIO.new(extract_file, ext))
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
    @is_unzip
  end
end
