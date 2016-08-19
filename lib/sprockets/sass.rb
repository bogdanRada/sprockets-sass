# frozen_string_literal: true
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
    # We need this only for Sprockets > 3 in order to be able to register anything.
    # For Sprockets 2.x , although the file and the module name exist,
    # they can't be used because it will give errors about undefined methods, because this is included only on Sprockets::Base
    # and in order to use them we would have to subclass it and define methods to expire cache and other methods for registration ,
    # which are not needed since Sprockets already  knows about that using the environment instead internally
    require 'sprockets/processing'
    extend Sprockets::Processing

    # We need this for Sprockets > 3 for the ERB processor to work with SASS and SCSS also , besides CSS
    register_mime_type 'application/scss+ruby', extensions: ['.scss.erb', '.css.scss.erb']
    register_mime_type 'application/sass+ruby', extensions: ['.sass.erb', '.css.sass.erb']

    # The new way of registering the compressor, uses a name given as a symol, instead of using the class directly
    # e.g
    #
    #  Rails.application.configure do |config|
    #    config.css_compressor = Sprockets::Sass::Compressor # This works only for Sprockets 2.x
    #     config.css_compressor = :sprockets_sass # This works with Sprockets > 3
    #   end
    #
    register_compressor 'text/css', :sprockets_sass, Sprockets::Sass::Compressor
  end

  # We use the register engine for Sprockets 2.x and 3.x because they work like preprocessors
  # and both version are using tex/css as a mime type for SASS and SCSS so we are using same mime type here also
  #
  # Sprockets 4 doesn't know about register_engine and uses transformers instead for SASS and SCSS
  # and uses different mime types for SASS and SCSS
  if respond_to?(:register_engine)
    if respond_to?(:register_transformer)
      # We need to do this only for Sprockets 3.x since the Erb Processor is now registered only for CSS but no SASS or SCSS
      # this works well, because the importer knows how to call the transformers
      # and other processors and other engines when evaluating a filename
      # @see Sprockets::Sass:Importer#evaluate
      # @see Sprockets::Sass:Importer#process
      #
      register_transformer 'application/scss+ruby', 'text/css', Sprockets::ERBProcessor
      register_transformer 'application/sass+ruby', 'text/css', Sprockets::ERBProcessor
    end
    args = ['.sass', Sprockets::Sass::SassTemplate]
    args << { mime_type: 'text/css', extensions: ['.sass', '.css.sass'], silence_deprecation: true } if Sprockets::Sass.version_of_sprockets >= 3
    register_engine(*args)
    args = ['.scss', Sprockets::Sass::ScssTemplate]
    args << { mime_type: 'text/css', extensions: ['.scss', '.css.scss'], silence_deprecation: true } if Sprockets::Sass.version_of_sprockets >= 3
    register_engine(*args)
  else
    #  THis code is executed only for Sprockets 4
    # Sprockets 4 introduces new mime types text/sass and text/scss
    # and uses transformers to transform to css

    # The mime types are already registered, but added here just in case , to have some history about what we used
    # Doesn't affect anything
    register_mime_type 'text/sass', extensions: ['.sass', '.css.sass']
    register_mime_type 'text/scss', extensions: ['.scss', '.css.scss']

    # Since Sprockets 4 introduces the text/sass and text/scss , this transfomer needs to use the new mime types instead of text/css
    register_transformer 'application/scss+ruby', 'text/scss', Sprockets::ERBProcessor
    register_transformer 'application/sass+ruby', 'text/sass', Sprockets::ERBProcessor

    # @TODO [ONLY Sprockets >= 4] The importer is messed up , Neeed to fix it,
    # In previous versions, the preprocessors , engines and transformers registered,
    # would have been a list of Classes ( with the actual class names of the preprocessors or engines ) and Procs ( The transformers  which don't need to be filtered )
    # The only thing that needed to be filtred was the preprocessors and engines which was easy by checking the class name
    #
    # Sprockets 4 though registration messes everything up because now because uses transformers for SASS and SCSS,
    # and there is no way of telling from a Proc what transformer was used to create the Proc.
    # also uses anonymous classes which can't be filtered. Still trying to investigate how to filter them.
    # And some of the classes don't respond to call but to render. Very Crazy stuff here going on!!!
    #
    # Also In sprockets 4 seems both text/css and text/scss and text/sass are used as mime types.
    # This leads to registering same preprocessor twice (once for text/sass and text/css ) or (text/scss and text/css)
    # Can't find a workaround registering it only one time each preprocessor :(
    # The only solution would be to use a transformer, but the Sprockets transformers are executed first, which
    # return text/css and crash because the SASS engine don't know about some directives that this gem is using.
    # So our transformers are never executed. So for now we're using preprocessors until we find a better workaround
    # or a way of hooking up a tranformer before another transformer.
    #
    # AND ALSO TRANSFORMERS CAN'T BE UNREGISTERED !!! :(
    #
    # In previous version of Sprockets this would work, because they used engines ( which work like  preprocessors )
    register_preprocessor 'text/sass', Sprockets::Sass::SassTemplate
    register_preprocessor 'text/scss', Sprockets::Sass::ScssTemplate
    register_preprocessor 'text/css',  Sprockets::Sass::SassTemplate
    register_preprocessor 'text/css', Sprockets::Sass::ScssTemplate

  end
end
