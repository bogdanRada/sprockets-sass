# frozen_string_literal: true
require_relative '../v3/sass_template'
module Sprockets
  module Sass
    module V4
      # Preprocessor for SASS files
      class SassTemplate < Sprockets::Sass::V3::SassTemplate

        def self.default_mime_type
          "text/#{syntax}"
        end

        # Allow the use of custom SASS importers, making sure the
        # custom importer is a `Sprockets::Sass::Importer`
        def fetch_importer_class
          if defined?(@importer_class) && !@importer_class.nil?
            @importer_class
          elsif default_sass_options.key?(:importer) && default_sass_options[:importer].is_a?(Importer)
            default_sass_options[:importer]
          else
            Sprockets::Sass::V4::Importer.new
          end
        end


      end
    end
  end
end
