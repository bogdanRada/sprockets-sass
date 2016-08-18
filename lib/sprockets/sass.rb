require 'sprockets'
require 'sprockets/sass/version'
require 'sprockets/sass/utils'
require 'sprockets/sass/sass_template'
require 'sprockets/sass/scss_template'
require 'sprockets/sass/functions'
require 'json'

module Sprockets
  module Sass
    autoload :LegacyCacheStore, 'sprockets/sass/legacy_cache_store'
    autoload :CacheStore, 'sprockets/sass/cache_store'
    autoload :Compressor, 'sprockets/sass/compressor'
    autoload :Importer,   'sprockets/sass/importer'
    class << self
      # Global configuration for `Sass::Engine` instances.
      attr_accessor :options

      # When false, the asset path helpers provided by
      # sprockets-helpers will not be added as Sass functions.
      # `true` by default.
      attr_accessor :add_sass_functions

      def version_of_sprockets
        Sprockets::VERSION.split('.')[0].to_i
      end

    end

    @options = {}
    @add_sass_functions = true
  end

  begin # Newwer sprockets -- Need to make sure this are defined
    require 'sprockets/directive_processor'
    require 'sprockets/sass_processor'
    require 'sprockets/sassc_processor'
    require 'sprockets/digest_utils'
    require 'sprockets/engines'
  rescue LoadError; end

  if Sprockets::Sass.version_of_sprockets >= 3
    require 'sprockets/processing'
    extend Sprockets::Processing
    register_mime_type 'application/scss+ruby', extensions: ['.scss.erb', '.css.scss.erb']
    register_mime_type 'application/sass+ruby', extensions: ['.sass.erb', '.css.sass.erb']
    register_compressor 'text/css', :sprockets_sass, Sprockets::Sass::Compressor
    register_transformer 'application/scss+ruby', 'text/css', Sprockets::ERBProcessor
    register_transformer 'application/sass+ruby', 'text/css', Sprockets::ERBProcessor
  end

  if respond_to?(:register_engine)
    args = ['.sass', Sprockets::Sass::SassTemplate]
    args << { mime_type: 'text/css', extensions: ['.sass', '.css.sass'],  silence_deprecation: true } if Sprockets::Sass.version_of_sprockets >= 3
    register_engine(*args)
    args = ['.scss', Sprockets::Sass::ScssTemplate]
    args << { mime_type: 'text/css', extensions: ['.scss', '.css.scss'], silence_deprecation: true } if Sprockets::Sass.version_of_sprockets >= 3
    register_engine(*args)
  else # Sprockets 4
    register_mime_type 'text/sass', extensions: ['.sass', '.css.sass']
    register_mime_type 'text/scss', extensions: ['.scss', '.css.scss']
    register_transformer 'application/scss+ruby', 'text/scss', Sprockets::ERBProcessor
    register_transformer 'application/sass+ruby', 'text/sass', Sprockets::ERBProcessor
    register_preprocessor 'text/sass',  Sprockets::Sass::SassTemplate
    register_preprocessor 'text/scss',  Sprockets::Sass::ScssTemplate
    register_preprocessor 'text/css',  Sprockets::Sass::SassTemplate
    register_preprocessor 'text/css',  Sprockets::Sass::ScssTemplate
  end

end
