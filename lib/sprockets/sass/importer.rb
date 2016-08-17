require 'sass/importers/base'
require 'pathname'

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
        if Sprockets::Sass.version_of_sprockets >= 3
          possible_files(context, path, base_path).each do |file|
            found_item  = context.resolve(file.to_s, load_paths: context.environment.paths, base_path: base_path , accept: syntax_mime_type(file)) rescue nil
            return found_item if !found_item.nil? && asset_requirable?(context, found_item)
          end
        else
          possible_files(context, path, base_path).each do |file|
            context.resolve(file.to_s) do  |found|
              return found if context.asset_requirable?(found)
            end
          end
        end

        nil
      end

      def asset_requirable?(context, path)
      pathname = context.resolve(path)
      content_type = syntax_mime_type(path)
      stat = context.environment.stat(path)
      return false unless stat && stat.file?
      true
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
        additional_paths = [Pathname.new("#{base_name}.css"),  Pathname.new("#{partial_path}.css")]
        paths     = additional_paths.concat(["#{path}", "#{partial_path}" ])

        if Sprockets::Sass.version_of_sprockets >= 3
          paths = paths.map {|path| path.to_s.start_with?('.') || path.to_s.include?('*') ? path : Pathname.new(path.to_s.prepend('./')) }
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
        paths.compact
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
        classes
      end



      # Internal: Run processors on filename and data.
      #
      # Returns Hash.
      def process(processors, context, path)
        data = Sprockets::Sass::Utils.read_template_file(path.to_s)

        input = {
          environment: context.environment,
          cache: context.environment.cache,
          uri: path.to_s ,
          filename: path.to_s,
          load_path: context.environment.paths,
          name: File.basename(path),
          content_type: syntax_mime_type(path),
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
        attributes = context.environment.respond_to?(:attributes_for) ? context.environment.attributes_for(path) : context.environment.send(:parse_path_extnames,path.to_s)
        content_type = attributes.respond_to?(:content_type) ? attributes.content_type : attributes[1]
        engines = attributes.respond_to?(:engines) ? attributes.engines : []
        preprocessors =  Sprockets::Sass.version_of_sprockets >= 3 ? context.environment.preprocessors[content_type].map {|a| a.class } : context.environment.preprocessors(content_type)
        processors =  preprocessors + engines.reverse
        processors.delete_if { |processor| filtered_processor_classes.include?(processor) || filtered_processor_classes.any?{|filtered_processor| processor < filtered_processor  } }
        context.respond_to?(:evaluate) ? context.evaluate(path, :processors => processors) : process(processors, context , path)
      end
    end
  end
end
