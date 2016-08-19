# frozen_string_literal: true
module Sprockets
  module Sass
    # Internal: Cache wrapper for Sprockets cache adapter.
    class CacheStore < ::Sass::CacheStores::Base
      VERSION = '1'

      def initialize(cache, version)
        @cache = cache
        @version = "#{VERSION}/#{version}"
      end

      def _store(key, version, sha, contents)
        @cache.set("#{@version}/#{version}/#{key}/#{sha}", contents, true)
      end

      def _retrieve(key, version, sha)
        @cache.get("#{@version}/#{version}/#{key}/#{sha}", true)
      end

      def path_to(key)
        key
      end
    end
  end
end
