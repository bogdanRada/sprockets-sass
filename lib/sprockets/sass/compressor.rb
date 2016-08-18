require 'sass'

module Sprockets
  module Sass
    class Compressor
      VERSION = '1'

      def self.default_mime_type
        'text/css'
      end
      # Public: Return singleton instance with default options.
      #
      # Returns SassCompressor object.
      def self.instance
        @instance ||= new
      end

      def self.call(input)
        instance.call(input)
      end

      def self.cache_key
        instance.cache_key
      end

      attr_reader :cache_key, :input, :filename, :source, :options

      def initialize(options = {}, &block)
        @default_options  = {
          syntax: :scss,
          cache: false,
          read_cache: false,
          style: :compressed,
          default_encoding: Encoding.default_external || 'utf-8'
        }
        @options = @default_options
        @cache_key = "#{self.class.name}:#{::Sass::VERSION}:#{VERSION}:#{Sprockets::Sass::Utils.digest(options)}".freeze
        if options.is_a?(Hash)
          @input = options
          @filename = options[:filename]
          @source = options[:data]
          @options = @options.merge(options)
        else
          @filename = options
          @source = block_given? ? block.call : nil
        end
      end

      def call(input)
        @input = input
        @filename = input[:filename]
        @source   = input[:data]
        run
      end


      def render(context, empty_hash_wtf)
        @context = context
        run
      end


      def run
        data = Sprockets::Sass::Utils.read_file_binary(filename, options)
        if data.count("\n") > 2
          engine = ::Sass::Engine.new(data, @options.merge(filename: filename))
          if defined?(Sprockets::SourceMapUtils) && engine.respond_to?(:render_with_sourcemap)
            css, map = engine.render_with_sourcemap('')

            css = css.sub("/*# sourceMappingURL= */\n", '')

            map = Sprockets::SourceMapUtils.combine_source_maps(
            input[:metadata][:map],
            Sprockets::SourceMapUtils.decode_json_source_map(map.to_json(css_uri: 'uri'))["mappings"]
            )

            { data: css, map: map }
          else
            engine.render
          end
        else
          Sprockets::Sass.version_of_sprockets >= 3 ? { data: data } : data
        end
      end

    end
  end
end
