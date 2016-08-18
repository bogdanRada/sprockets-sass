module Sprockets
  module Sass
    class SassTemplate
      VERSION = '1'

      def self.default_mime_type
        Sprockets.respond_to?(:register_engine) ? 'text/css' : "text/#{syntax}"
      end
      # Internal: Defines default sass syntax to use. Exposed so the ScssProcessor
      # may override it.
      def self.syntax
        :sass
      end

      # Public: Return singleton instance with default options.
      #
      # Returns SassProcessor object.
      def self.instance
        @instance ||= new
      end

      def self.call(input)
        instance.call(input)
      end


      def self.cache_key
        instance.cache_key
      end

      attr_reader :cache_key, :filename, :source, :context, :options

      def initialize(options = {}, &block)
        default_options  = { default_encoding: Encoding.default_external || 'utf-8' }
        initialize_engine
        if options.is_a?(Hash)
          @cache_version = options[:cache_version] || VERSION
          @cache_key = "#{self.class.name}:#{::Sass::VERSION}:#{@cache_version}:#{Sprockets::Sass::Utils.digest(options)}".freeze
          @filename = options[:filename]
          @source = options[:data]
          @options = options.merge(default_options)
          @importer_class = options[:importer]
          @sass_config = options[:sass_config] || {}
          @input = options
          @functions = Module.new do
            include Sprockets::Helpers if defined?(Sprockets::Helpers)
            include Sprockets::Sass::Functions
            include options[:functions] if options[:functions]
            class_eval(&block) if block_given?
          end
        else
          @filename = options
          @source = block.call
          @options = default_options
          @cache_version = VERSION
          @cache_key = "#{self.class.name}:#{::Sass::VERSION}:#{VERSION}:#{Sprockets::Sass::Utils.digest(options)}".freeze
          @functions = Module.new do
            include Sprockets::Helpers if defined?(Sprockets::Helpers)
            include Sprockets::Sass::Functions
          end
        end
      end

      @sass_functions_initialized = false
      class << self
        attr_accessor :sass_functions_initialized
        alias :sass_functions_initialized? :sass_functions_initialized
        # Templates are initialized once the functions are added.
        def engine_initialized?
          sass_functions_initialized?
        end
      end

      # Add the Sass functions if they haven't already been added.
      def initialize_engine
        return if self.class.engine_initialized?

        if Sass.add_sass_functions != false
          begin
            require 'sprockets/helpers'
            require 'sprockets/sass/functions'
            self.class.sass_functions_initialized = true
          rescue LoadError; end
        end
      end

      def call(input)
        @input = input
        @filename = input[:filename]
        @source   = input[:data]
        @context  = input[:environment].context_class.new(input)
        run
      end


      def render(context, empty_hash_wtf)
        @context = context
        run
      end



      def run
        begin
          data = Sprockets::Sass::Utils.read_file_binary(filename, options)

          engine = ::Sass::Engine.new(data, sass_options)

          css = Sprockets::Sass::Utils.module_include(::Sass::Script::Functions, @functions) do
            css = engine.render
          end

          sass_dependencies = Set.new([filename])
          if context.respond_to?(:metadata)
            engine.dependencies.map do |dependency|
              sass_dependencies << dependency.options[:filename]
              context.metadata[:dependencies] << Sprockets::URIUtils.build_file_digest_uri(dependency.options[:filename])
            end
            context.metadata.merge(data: css, sass_dependencies: sass_dependencies)
          else
            css
          end



          #  Tilt::SassTemplate.new(filename, sass_options(filename, context)).render(self)
        rescue ::Sass::SyntaxError => e
          # Annotates exception message with parse line number
          #context.__LINE__ = e.sass_backtrace.first[:line]
          raise [e, e.sass_backtrace].join("\n")
        end
      end


      def merge_sass_options(options, other_options)
        if (load_paths = options[:load_paths]) && (other_paths = other_options[:load_paths])
          other_options[:load_paths] = other_paths + load_paths
        end
        options = options.merge(other_options)
        options[:load_paths] = options[:load_paths].concat(context.environment.paths)
        options
      end

      def default_sass_options
        if defined?(Compass)
          sass = merge_sass_options Compass.sass_engine_options.dup, Sprockets::Sass.options
        else
          sass = Sprockets::Sass.options.dup
        end
        sass = merge_sass_options(sass.dup, @sass_config) if defined?(@sass_config) && @sass_config.is_a?(Hash)
        sass
      end



      def cache_store(context)
        return nil if context.environment.cache.nil?

        if Sprockets::Sass.version_of_sprockets < 3
          if defined?(Sprockets::SassCacheStore)
            Sprockets::SassCacheStore.new context.environment
          else
            Sprockets::Sass::LegacyCacheStore.new context.environment
          end
        else
          if defined?(Sprockets::SassProcessor::CacheStore)
            Sprockets::SassProcessor::CacheStore.new(@input[:cache], @cache_version)
          else
            Sprockets::Sass::CacheStore.new(@input[:cache], @cache_version)
          end
        end
      end



      def syntax_file(path)
        path.to_s.include?('.sass') ? :sass : :scss
      end

      def sass_options
        # Allow the use of custom SASS importers, making sure the
        # custom importer is a `Sprockets::Sass::Importer`
        if defined?(@importer_class) && !@importer_class.nil?
          importer = @importer_class
        elsif default_sass_options.key?(:importer) && default_sass_options[:importer].is_a?(Importer)
          importer = default_sass_options[:importer]
        else
          importer = Sprockets::Sass::Importer.new
        end

        sprockets_options = {
          context: context,
          environment: context.environment,
          dependencies: context.respond_to?(:metadata) ? context.metadata[:dependencies] : []
        }
        if context.respond_to?(:metadata)
          sprockets_options.merge(load_paths: context.environment.paths + default_sass_options[:load_paths] )
        end

        sass = merge_sass_options(default_sass_options, options).merge(
        :filename    => filename,
        :line        => 1,
        :syntax      => self.class.syntax,
        :cache       => true,
        :cache_store       => cache_store(context),
        :importer    => importer,
        :custom      => { :sprockets_context => context },
        sprockets: sprockets_options
        )
        sass
      end


    end
  end
end
