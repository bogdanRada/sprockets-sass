module Sprockets
  module Sass
    class SassTemplate

      def initialize(filename, &block)
        @filename = filename
        @source   = block.call
        initialize_engine
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
          rescue LoadError; end
        end

        self.class.sass_functions_initialized = true
      end

      def render(context, empty_hash_wtf)
        self.class.run(@filename, @source, context)
      end

      def self.read_template_file(file)
        data = File.open(file, 'rb') { |io| io.read }
        if data.respond_to?(:force_encoding)
          # Set it to the default external (without verifying)
          data.force_encoding(Encoding.default_external) if Encoding.default_external
        end
        data
      end

      def self.run(filename, source, context)
        begin
          Tilt::SassTemplate.new(filename, sass_options(filename, context)).render(self)
        rescue ::Sass::SyntaxError => e
          # Annotates exception message with parse line number
          context.__LINE__ = e.sass_backtrace.first[:line]
          raise e
        end
      end
      
      def self.call(input)
        filename = input[:filename]
        source   = input[:data]
        context  = input[:environment].context_class.new(input)
        result = run(filename, source, context)
        context.metadata.merge(data: result)
      end


      def self.read_template_file(file)
        data = File.open(file, 'rb') { |io| io.read }
        if data.respond_to?(:force_encoding)
          # Set it to the default external (without verifying)
          data.force_encoding(Encoding.default_external) if Encoding.default_external
        end
        data
      end

      def self.merge_sass_options(options, other_options)
        if (load_paths = options[:load_paths]) && (other_paths = other_options[:load_paths])
          other_options[:load_paths] = other_paths + load_paths
        end
        options.merge other_options
      end

      def self.default_sass_options
        if defined?(Compass)
          merge_sass_options Compass.sass_engine_options.dup, Sprockets::Sass.options
        else
          Sprockets::Sass.options.dup
        end
      end

      def self.syntax
        :sass
      end

      def self.cache_store(context)
        return nil if context.environment.cache.nil?

        if defined?(Sprockets::SassCacheStore)
          Sprockets::SassCacheStore.new context.environment
        else
          Sprockets::Sass::CacheStore.new context.environment
        end
      end

      def self.options
        {
          default_encoding: 'utf-8'
        }
      end

      def self.syntax_file(path)
        path.to_s.include?('.sass') ? :sass : :scss
      end

      def self.sass_options(filename, context)
        # Allow the use of custom SASS importers, making sure the
        # custom importer is a `Sprockets::Sass::Importer`
        if default_sass_options.has_key?(:importer) &&
          default_sass_options[:importer].is_a?(Importer)
          importer = default_sass_options[:importer]
        else
          importer = Sprockets::Sass::Importer.new
        end

        merge_sass_options(default_sass_options, options).merge(
        :filename    => filename,
        :line        => 1,
        :syntax      => syntax_file(filename) || syntax,
        :cache_store => cache_store(context),
        :importer    => importer,
        :custom      => { :sprockets_context => context }
        )
      end


    end
  end
end
