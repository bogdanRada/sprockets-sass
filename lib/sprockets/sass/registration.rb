module Sprockets
  module Sass
    class Registration

      attr_reader :klass

      DEFAULT_ACTION = { min_comparison: '>=' , min: 2, max_comparison: '<', max: 3,   action: :register_sprockets_legacy }

      ACTIONS = [
        { min_comparison: '>=' , min: 3, max_comparison: '<', max: 4,   action: :register_sprockets_v3 },
        { min_comparison: '>=' , min: 4,  action: :register_sprockets_v4 }
      ]

      attr_reader :klass, :sprockets_version, :registration_instance, :action_details, :version_selected

      def initialize(klass)
        @klass = klass
        @sprockets_version = Sprockets::Sass::Utils.version_of_sprockets
        @registration_instance = self
        @action_details = action_to_be_executed
        @version_selected = @action_details[:min]
      end

      def run
        require_libraries
        send(@action_details[:action])
      end

      def require_libraries
        require_standard_libraries(version_selected -1) if sprockets_version >= 4
        require_standard_libraries(version_selected)
        require 'sprockets/sass/functions'
      end
      
      private

      def require_standard_libraris(version)
        %w{ cache_store compressor functions importer sass_template scss_template}.each do |filename|
          require "sprockets/sass/v#{version}/#{filename}"
        end
      end

      def register_sprockets_v3_common
        %w(sass scss).each do |mime|
          _register_mime_types(mime_type:  "application/#{mime}+ruby", extensions: [".#{mime}.erb", ".css.#{mime}.erb"])
        end
        _register_compressors(mime_type: 'text/css',name: :sprockets_sass, klass: Sprockets::Sass::Utils.get_class_by_version("Compressor"))
      end


      def register_sprockets_v4
        register_sprockets_v3_common
        %w(sass scss).each do |mime|
          _register_transformers(from: "application/#{mime}+ruby", to: "text/#{mime}", klass: Sprockets::ERBProcessor)
        end
        _register_v4_preprocessors( Sprockets::Sass::Utils.get_class_by_version("SassTemplate") => ['text/sass', 'text/css'] ,  Sprockets::Sass::Utils.get_class_by_version("ScssTemplate") => ['text/scss', 'text/css'] )
      end

      def register_sprockets_v3
        register_sprockets_v3_common
        _register_transformers(
        {from: 'application/scss+ruby', to: 'text/css', klass: Sprockets::ERBProcessor},
        {from: 'application/sass+ruby', to: 'text/css', klass: Sprockets::ERBProcessor}
        )
        _register_engines('.sass' => Sprockets::Sass::V3::SassTemplate, '.scss' => Sprockets::Sass::V3::ScssTemplate)
      end

      def register_sprockets_legacy
        _register_engines('.sass' => Sprockets::Sass::V2::SassTemplate, '.scss' => Sprockets::Sass::V2::ScssTemplate)
      end

      def _register_engines(hash)
        hash.each do |key, value|
          args = [key, value]
          args << { mime_type: 'text/css', silence_deprecation: true } if sprockets_version >= 3
          register_engine(*args)
        end
      end

      def action_to_be_executed
        action = ACTIONS.find { |action_data| sprockets_valid_version?(action_data) }
        action = action.nil? && sprockets_valid_version?(Sprockets::Sass::Registration::DEFAULT_ACTION) ?  Sprockets::Sass::Registration::DEFAULT_ACTION : action
        raise "Version #{@sprockets_version} is not supported" if action.nil?
        action
      end


      def sprockets_valid_version?(action_data)
        if action_data.key?(:min) && action_data.key(:max)
          @sprockets_version.send(action_data[:min_comparison], action_data[:min]) &&
          @sprockets_version.send(action_data[:max_comparison], action_data[:max])
        elsif action_data.key?(:min)
          @sprockets_version.send(action_data[:min_comparison], action_data[:min])
        end
      end

      def _register_mime_types(*mime_types)
        mime_types.each do |mime_data|
          register_mime_type(mime_data[:mime_type], extensions: mime_data[:extensions])
        end
      end

      def _register_compressors(*compressors)
        compressors.each do |compressor|
          register_compressor(compressor[:mime_type], compressor[:name], compressor[:klass])
        end
      end



      def _register_transformers(*tranformers)
        tranformers.each do |tranformer|
          register_transformer(tranformer[:from], tranformer[:to], tranformer[:klass])
        end
      end

      def _register_v4_preprocessors(hash)
        hash.each do |key, value|
          value.each do |mime|
            register_preprocessor(mime, key)
          end
        end
      end

      def method_missing(sym, *args, &block)
        @klass.public_send(sym, *args, &block) || super
      end

      def respond_to_missing?(method_name, include_private = nil)
        include_private = include_private.blank? ? true : include_private
        @klass.public_methods.include?(method_name) || super(method_name, include_private)
      end

    end
  end
end
