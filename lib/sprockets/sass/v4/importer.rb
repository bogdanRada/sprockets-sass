# frozen_string_literal: true
require_relative '../v3/importer'
module Sprockets
  module Sass
    module V4
      # class used for importing files from SCCS and SASS files
      class Importer < Sprockets::Sass::V3::Importer

        def stat_of_pathname(context, pathname, _path)
          asset = context.environment.load(pathname)
          context.environment.stat(asset.filename)
        end

        def content_type_of_path(context, path)
          pathname = resolve_path_with_load_paths(context, path)
          content_type = pathname.nil? ? nil : pathname.to_s.scan(/\?type\=(.*)/).flatten.first unless pathname.nil?
          attributes = {}
          [content_type, attributes]
        end
      end
    end
  end
end
