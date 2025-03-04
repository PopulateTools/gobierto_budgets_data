# frozen_string_literal: true

module GobiertoBudgetsData
  module FileUploaderService
    class Local
      FILE_PATH_PREFIX = "system/attachments"

      attr_reader :file, :file_name

      def initialize(file:, file_name:)
        @file = file
        @file_name = file_name
      end

      def call
        upload || file_uri
      end

      def upload
        upload! if !uploaded_file_exists? && @file
      end

      def upload!
        FileUtils.mkdir_p(file_base_path) unless File.exist?(file_base_path)
        FileUtils.mv(file.tempfile.path, file_path)
        File.chmod(0o664, file_path)
        ObjectSpace.undefine_finalizer(file.tempfile)

        file_uri
      end

      def uploaded_file_exists?
        File.exist?(file_path)
      end

      private

      def file_uri
        File.join("/", FILE_PATH_PREFIX, file_name)
      end

      def file_path
        File.join(file_base_path, file_basename)
      end

      def file_base_path
        File.join(
          ENV.fetch("GOBIERTO_PUBLIC_PATH"),
          FILE_PATH_PREFIX,
          file_dirname
        )
      end

      protected

      def file_dirname
        Pathname.new(file_name).dirname
      end

      def file_basename
        Pathname.new(file_name).basename
      end
    end
  end
end
