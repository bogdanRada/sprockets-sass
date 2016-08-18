require 'sass'

module Sprockets
  module Sass
    class Compressor
      VERSION = '1'

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

      attr_reader :cache_key

      def initialize(options = {}, &block)
        @default_options  = {
          syntax: :scss,
          cache: false,
          read_cache: false,
          style: :compressed
        }
        @cache_key = "#{self.class.name}:#{::Sass::VERSION}:#{VERSION}:#{Sprockets::Sass::Utils.digest(options)}".freeze
        if options.is_a?(Hash)
          @options = @default_options.merge(options).freeze
        elsif options.is_a?(String)
          @filename = options
          @source = block.call
          @options = @default_options.freeze
        end
      end



      def call(input)
        if input[:data].count("\n") > 2
          engine = ::Sass::Engine.new(input[:data], @options.merge(filename: 'filename'))
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
          {data: input[:data]}
        end
      end

    end
  end
end
