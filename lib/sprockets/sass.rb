require 'sprockets'
require 'sprockets/sass/version'
require 'sprockets/sass/sass_template'
require 'sprockets/sass/scss_template'
require 'sprockets/engines'
require 'tilt'
Tilt::SassTemplate.class_eval do
  alias_method :original_sass_options, :sass_options
  def sass_options
    options.merge(:filename => eval_file, :line => line, :syntax => options[:syntax] || :sass)
  end
end

module Sprockets
  module Sass
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
    end

    @options = {}
    @add_sass_functions = true
  end

  if respond_to?(:register_transformer)
    require 'sprockets/processing'
    extend Sprockets::Processing
    register_mime_type 'text/css', extensions: ['.sass'], charset: :css
    register_mime_type 'text/css', extensions: ['.scss'], charset: :css
    register_preprocessor 'text/sass',Sprockets::Sass::SassTemplate
    register_preprocessor 'text/scss', Sprockets::Sass::ScssTemplate
  else
    args = ['.sass', Sprockets::Sass::SassTemplate]
    args << { mime_type: 'text/css', silence_deprecation: true } if Sprockets::VERSION.start_with?("3")
    register_engine(*args)
    args = ['.scss', Sprockets::Sass::ScssTemplate]
    args << { mime_type: 'text/css', silence_deprecation: true } if Sprockets::VERSION.start_with?("3")
    register_engine(*args)
  end

end
