# frozen_string_literal: true
require_relative '../v2/sass_template'
module Sprockets
  module Sass
    module V3
      # Preprocessor for SASS files
      class SassTemplate < Sprockets::Sass::V2::SassTemplate
        def build_cache_store(context)
          return nil if context.environment.cache.nil?
          cache = @input[:cache]
          version = @cache_version
          if defined?(Sprockets::SassProcessor::CacheStore)
            Sprockets::SassProcessor::CacheStore.new(cache, version)
          else
            custom_cache_store(cache, version)
          end
        end

        def custom_cache_store(*args)
          Sprockets::Sass::V3::CacheStore.new(*args)
        end

        def custom_importer_class(*_args)
          Sprockets::Sass::V3::Importer.new
        end

      end
    end
  end
end
