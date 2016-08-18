require 'sass/importers/base'
require 'pathname'

#Sprockets 4 needs this , becasue it doesnt use ::Sass in code
Sprockets::Sass::Importers = ::Sass::Importers

module Sprockets
  module Sass
    class Importer < ::Sass::Importers::Base
      GLOB = /\*|\[.+\]/


      # @see Sass::Importers::Base#find_relative
      def find_relative(path, base_path, options)
        if path.to_s =~ GLOB
          engine_from_glob(path, base_path, options)
        else
          engine_from_path(path, base_path, options)
        end
      end

      # @see Sass::Importers::Base#find
      def find(path, options)
        engine_from_path(path, nil, options)
      end

      # @see Sass::Importers::Base#mtime
      def mtime(path, options)
        if pathname = resolve(path)
          pathname.mtime
        end
      rescue Errno::ENOENT
        nil
      end

      # @see Sass::Importers::Base#key
      def key(path, options)
        path = Pathname.new(path)
        ["#{self.class.name}:#{path.dirname.expand_path}", path.basename]
      end

      # @see Sass::Importers::Base#to_s
      def to_s
        self.inspect
      end

      protected

      # Create a Sass::Engine from the given path.
      def engine_from_path(path, base_path, options)
        context = options[:custom][:sprockets_context]
        pathname = resolve(context, path, base_path) or return nil
        context.depend_on pathname
        ::Sass::Engine.new evaluate(context, pathname), options.merge(
        :filename => pathname.to_s,
        :syntax   => syntax(pathname),
        :importer => self,
        :custom      => { :sprockets_context => context }
        )
      end

      # Create a Sass::Engine that will handle importing
      # a glob of files.
      def engine_from_glob(glob, base_path, options)
        context = options[:custom][:sprockets_context]
        imports = resolve_glob(context, glob, base_path).inject('') do |imports, path|
          context.depend_on path
          relative_path = path.relative_path_from Pathname.new(base_path).dirname
          imports << %(@import "#{relative_path}";\n)
        end
        return nil if imports.empty?
        ::Sass::Engine.new imports, options.merge(
        :filename => base_path.to_s,
        :syntax   => syntax(base_path.to_s),
        :importer => self,
        :custom      => { :sprockets_context => context }
        )
      end

      # Finds an asset from the given path. This is where
      # we make Sprockets behave like Sass, and import partial
      # style paths.
      def resolve(context, path, base_path)
        paths, root_path = possible_files(context, path, base_path)
        if Sprockets::Sass.version_of_sprockets >= 3
          paths.each do |file|
            found_item  = context.resolve(file.to_s, load_paths: context.environment.paths, base_path: root_path , accept: syntax_mime_type(path)) rescue nil
            return found_item if !found_item.nil?  && asset_requirable?(context, found_item)
          end
        else
          paths.each do |file|
            context.resolve(file.to_s) do  |found|
              return found if context.asset_requirable?(found)
            end
          end
        end

        nil
      end

      def asset_requirable?(context, path)
        available_content_types = ['text/css', syntax_mime_type(path), "text/#{syntax(path)}+ruby"]
        pathname = context.resolve(path.to_s) rescue nil
        return false if pathname.nil?
        path_content_type, attributes = content_type_of_path(context, path)
        if Sprockets::Sass.version_of_sprockets >= 4
          asset = context.environment.load(pathname)
          stat = context.environment.stat(asset.filename)
        else
          stat = context.environment.stat(path)
        end
        return false unless stat && stat.file?
        context.content_type.nil? || available_content_types.include?(path_content_type) || available_content_types.include?(context.content_type)
      end

      # Finds all of the assets using the given glob.
      def resolve_glob(context, glob, base_path)
        base_path      = Pathname.new(base_path)
        path_with_glob = base_path.dirname.join(glob).to_s

        Pathname.glob(path_with_glob).sort.select do |path|
          asset_requirable =  context.respond_to?(:asset_requirable?) ? context.asset_requirable?(path) : asset_requirable?(context, path)
          path != context.pathname && asset_requirable
        end
      end

      # Returns all of the possible paths (including partial variations)
      # to attempt to resolve with the given path.
      def possible_files(context, path, base_path)
        path      = Pathname.new(path)
        base_path = Pathname.new(base_path).dirname
        base_name = path.basename
        partial_path = partialize_path(path)
        additional_paths = [Pathname.new("#{path}.css"),  Pathname.new("#{partial_path}.css"),  Pathname.new("#{path}.css.#{syntax(path)}") ,  Pathname.new("#{partial_path}.css.#{syntax(path)}")]
        initial_paths = additional_paths.concat([path, partial_path])
        paths = initial_paths

        if Sprockets::Sass.version_of_sprockets >= 3
          relatives = paths.map {|path_detected| path_detected.to_s.start_with?('.') ? Pathname.new(path_detected) : Pathname.new(path_detected.to_s.prepend('./')) }
          file_level = path.to_s.split(File::SEPARATOR).size
          upper_levels = []
          file_level.times do |index|
            uper_paths = paths.map do |existing_path|
              string_to_prepend = '../' * (index + 1)
              Pathname.new(existing_path.to_s.prepend(string_to_prepend))
            end
            upper_levels.concat(uper_paths)
          end
          paths.concat(upper_levels)
          context.environment.paths.each do |load_path|
            relative_path = Pathname.new(base_path).relative_path_from(Pathname.new(load_path)).join(path)
            paths.unshift(relative_path, partialize_path(relative_path))
          end
          paths = paths.unshift(relatives)
        end
        # Find base_path's root
        env_root_paths = context.environment.paths.map {|p| Pathname.new(p) }
        root_path = env_root_paths.detect do |env_root_path|
          base_path.to_s.start_with?(env_root_path.to_s)
        end
        root_path ||= Pathname.new(context.root_path)
        # Add the relative path from the root, if necessary
        if path.relative? && base_path != root_path
          relative_path = base_path.relative_path_from(root_path).join path
          paths.unshift(relative_path, partialize_path(relative_path))
        end
        [paths.compact, root_path]
      end

      # Returns the partialized version of the given path.
      # Returns nil if the path is already to a partial.
      def partialize_path(path)
        if path.basename.to_s !~ /\A_/
          Pathname.new path.to_s.sub(/([^\/]+)\Z/, '_\1')
        end
      end

      def opposite_syntax(path)
        syntax(path) == :sass ? :scss : :sass
      end

      # Returns the Sass syntax of the given path.
      def syntax(path)
        path.to_s.include?('.sass') ? :sass : :scss
      end

      def syntax_mime_type(path)
        mime_type = Sprockets.respond_to?(:register_engine) ? 'text/css' : "text/#{syntax(path)}"
        mime_type
      end

      def filtered_processor_classes
        classes = [Sprockets::Sass::SassTemplate, Sprockets::Sass::ScssTemplate]
        classes << Sprockets::SassProcessor if defined?(Sprockets::SassProcessor)
        classes << Sprockets::ScssProcessor if defined?(Sprockets::ScssProcessor)
        classes << Sprockets::SasscProcessor if defined?(Sprockets::SasscProcessor)
        classes << Sprockets::ScsscProcessor if defined?(Sprockets::ScsscProcessor)
        classes << Sprockets::Preprocessors::DefaultSourceMap if defined?(Sprockets::Preprocessors::DefaultSourceMap)
        classes << Sprockets::SassCompressor if defined?(Sprockets::SassCompressor)
        classes << Sprockets::YUICompressor if defined?(Sprockets::YUICompressor)
        classes << Sprockets::SourceMapProcessor if defined?(Sprockets::SourceMapProcessor)
        classes
      end


      def content_type_of_path(context, path)
        if Sprockets::Sass.version_of_sprockets < 4
        attributes = context.environment.respond_to?(:attributes_for) ? context.environment.attributes_for(path) : context.environment.send(:parse_path_extnames, path.to_s)
        content_type = attributes.respond_to?(:content_type) ? attributes.content_type : attributes[1]
        else
          pathname = context.resolve(path.to_s) rescue nil
          content_type = pathname.nil? ? nil : pathname.to_s.scan(/\?type\=(.*)/).flatten.first unless pathname.nil?
          attributes = {}
        end
        [content_type, attributes]
      end


      # Internal: Run processors on filename and data.
      #
      # Returns Hash.
      def process(processors, context, path)
        if Sprockets::Sass.version_of_sprockets >= 4
          asset = context.environment.load(path) # because resolve now returns file://
          path = asset.filename
        end
        data = Sprockets::Sass::Utils.read_template_file(path.to_s)
        content_type, attributes = content_type_of_path(context, path)

        input = {
          environment: context.environment,
          cache: context.environment.cache,
          uri: path.to_s ,
          filename: path.to_s,
          load_path: context.environment.paths,
          name: File.basename(path),
          content_type: content_type,
          data: data,
          metadata: context.metadata
        }

        processors.each do |processor|
          begin
            result = processor.call(input)
            case result
            when NilClass
              # noop
            when Hash
              data = result[:data] if result.key?(:data)
              context.metadata.merge!(result)
              context.metadata.delete(:data)
              if result.key?(:required)
                result[:required].each do |file|
                  file_asset = context.environment.load(file)
                  data = data + process(processors, context, file_asset.filename)
                end
              end
            when String
              data = result
            else
              raise Error, "invalid processor return type: #{result.class}"
            end
          end
        end

        data
      end


      # Returns the string to be passed to the Sass engine. We use
      # Sprockets to process the file, but we remove any Sass processors
      # because we need to let the Sass::Engine handle that.
      def evaluate(context,  path)
        content_type, attributes = content_type_of_path(context, path)
        engines = attributes.respond_to?(:engines) ? attributes.engines : []
        preprocessors =  Sprockets::Sass.version_of_sprockets >= 3 ? context.environment.preprocessors[content_type].map {|a| a.class == Class ? a : a.class } : context.environment.preprocessors(content_type)
        available_transformers = context.environment.respond_to?(:transformers) ?  context.environment.transformers[content_type] : {}
        additional_transformers = available_transformers.key?(syntax_mime_type(path)) ? available_transformers[syntax_mime_type(path)] : []
        additional_transformers = additional_transformers.is_a?(Array) ? additional_transformers : [additional_transformers]
        processors =  additional_transformers.reverse + preprocessors + engines.reverse
        processors.delete_if { |processor|  filtered_processor_classes.include?(processor) || filtered_processor_classes.any?{|filtered_processor| !processor.is_a?(Proc)  && processor < filtered_processor  } }
        context.respond_to?(:evaluate) ? context.evaluate(path, :processors => processors) : process(processors, context , path)
      end
    end
  end
end
