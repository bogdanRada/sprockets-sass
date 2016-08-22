# frozen_string_literal: true
require_relative '../v2/sass_template'
module Sprockets
  module Sass
    module V3
      # Preprocessor for SASS files
      class SassTemplate < Sprockets::Sass::V2::SassTemplate

        def build_cache_store(context)
          return nil if context.environment.cache.nil?
          cache, version = @input[:cache], @cache_version
          if defined?(Sprockets::SassProcessor::CacheStore)
            Sprockets::SassProcessor::CacheStore.new(cache, version)
          else
            Sprockets::Sass::V3::CacheStore.new(cache, version)
          end
        end

        # Allow the use of custom SASS importers, making sure the
        # custom importer is a `Sprockets::Sass::Importer`
        def fetch_importer_class
          if defined?(@importer_class) && !@importer_class.nil?
            @importer_class
          elsif default_sass_options.key?(:importer) && default_sass_options[:importer].is_a?(Importer)
            default_sass_options[:importer]
          else
            Sprockets::Sass::V3::Importer.new
          end
        end


      end
    end
  end
end
