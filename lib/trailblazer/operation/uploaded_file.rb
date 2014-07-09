require 'trailblazer/operation'
require 'action_dispatch/http/upload'
require 'tempfile'

module Trailblazer
  # TODO: document:
  # to_hash
  # from_hash
  # initialize/tmp_dir
  class Operation::UploadedFile
    def initialize(uploaded, options={})
      @uploaded = uploaded
      @options  = options
      @tmp_dir  = options[:tmp_dir]
    end

    def to_hash
      path = persist!

      hash = {
        :filename       => @uploaded.original_filename,
        :type           => @uploaded.content_type,
        :tempfile_path  => path
      }

      cleanup!

      hash
    end

    # Returns a ActionDispatch::Http::UploadedFile as if the upload was in the same request.
    def self.from_hash(hash)
      file   = File.open(hash[:tempfile_path])
      suffix = File.extname(hash[:tempfile_path])

      # we need to create a Tempfile to make Http::UploadedFile work.
      tmp = Tempfile.new(["bla", suffix]) # always force file suffix to avoid problems with imagemagick etc.
      tmp.write(file.read) # DISCUSS: can we avoid that? slow!
      # unlink file

      hash[:tempfile] = tmp

      ActionDispatch::Http::UploadedFile.new(hash)
    end

  private
    attr_reader :tmp_dir

     # convert Tempfile from Rails upload into persistent "temp" file so it is available in workers.
    def persist!
      path = @uploaded.path # original Tempfile path (from Rails).
      path = path_with_tmp_dir(path)

      path = path + "_trailblazer_upload"

      FileUtils.mv(@uploaded.path, path)
      path
    end

    def path_with_tmp_dir(path)
      return path unless tmp_dir # if tmp_dir set, create path in it.

      @with_tmp_dir = Tempfile.new(File.basename(path), tmp_dir)
      @with_tmp_dir.path # use Tempfile to create nested dirs (os-dependent.)
    end

    def delete!(file)
      file.close
      file.unlink # the Rails uploaded file is already unlinked since moved.
    end

    def cleanup!
      @uploaded.close # this is Rails' uploaded file, not sure if we need to do that.
      delete!(@with_tmp_dir) if @with_tmp_dir # we used that file to create a tmp file path below tmp_dir.
    end
  end
end