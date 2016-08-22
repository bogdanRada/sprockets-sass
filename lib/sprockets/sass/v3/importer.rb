# frozen_string_literal: true

module Sprockets
  module Sass
    module V3
      # class used for importing files from SCCS and SASS files
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
        def mtime(path, _options)
          if pathname = resolve(path)
            pathname.mtime
          end
        rescue Errno::ENOENT
          nil
        end

        # @see Sass::Importers::Base#key
        def key(path, _options)
          path = Pathname.new(path)
          ["#{self.class.name}:#{path.dirname.expand_path}", path.basename]
        end

        # @see Sass::Importers::Base#to_s
        def to_s
          inspect
        end

        protected

        # Create a Sass::Engine from the given path.
        def engine_from_path(path, base_path, options)
          context = options[:custom][:sprockets_context]
          (pathname = resolve(context, path, base_path)) || (return nil)
          context.depend_on pathname
          ::Sass::Engine.new evaluate(context, pathname), options.merge(
          filename: pathname.to_s,
          syntax: syntax(pathname),
          importer: self,
          custom: { sprockets_context: context }
          )
        end

        # Create a Sass::Engine that will handle importing
        # a glob of files.
        def engine_from_glob(glob, base_path, options)
          context = options[:custom][:sprockets_context]
          engine_imports = resolve_glob(context, glob, base_path).reduce('') do |imports, path|
            context.depend_on path
            relative_path = path.relative_path_from Pathname.new(base_path).dirname
            imports << %(@import "#{relative_path}";\n)
          end
          return nil if engine_imports.empty?
          ::Sass::Engine.new engine_imports, options.merge(
          filename: base_path.to_s,
          syntax: syntax(base_path.to_s),
          importer: self,
          custom: { sprockets_context: context }
          )
        end

        def resolve_path_with_load_paths(context, path, root_path, file)
          context.resolve(file.to_s, load_paths: context.environment.paths, base_path: root_path, accept: syntax_mime_type(path))
        rescue
          nil
        end

        # Finds an asset from the given path. This is where
        # we make Sprockets behave like Sass, and import partial
        # style paths.
        def resolve(context, path, base_path)
          paths, root_path = possible_files(context, path, base_path)
          if Sprockets::Sass::Utils.version_of_sprockets >= 3
            paths.each do |file|
              found_item = resolve_path_with_load_paths(context, path, root_path, file)
              return found_item if !found_item.nil? && asset_requirable?(context, found_item)
            end
          else
            paths.each do |file|
              context.resolve(file.to_s) do |found|
                return found if context.asset_requirable?(found)
              end
            end
          end

          nil
        end

        def available_content_types(path)
          ['text/css', syntax_mime_type(path), "text/#{syntax(path)}+ruby"]
        end

        def resolve_path(context, path)
          context.resolve(path.to_s)
        rescue
          nil
        end

        def stat_of_pathname(context, pathname, path)
          if Sprockets::Sass::Utils.version_of_sprockets >= 4
            asset = context.environment.load(pathname)
            context.environment.stat(asset.filename)
          else
            context.environment.stat(path)
          end
        end

        def asset_requirable?(context, path)
          pathname = resolve_path(context, path)
          return false if pathname.nil?
          stat = stat_of_pathname(context, pathname, path)
          return false unless stat && stat.file?
          available_mimes = available_content_types(path)
          path_content_type, _attributes = content_type_of_path(context, path)
          context.content_type.nil? || available_mimes.include?(path_content_type) || available_mimes.include?(context.content_type)
        end

        # Finds all of the assets using the given glob.
        def resolve_glob(context, glob, base_path)
          base_path      = Pathname.new(base_path)
          path_with_glob = base_path.dirname.join(glob).to_s

          Pathname.glob(path_with_glob).sort.select do |path|
            asset_requirable = context.respond_to?(:asset_requirable?) ? context.asset_requirable?(path) : asset_requirable?(context, path)
            path != context.pathname && asset_requirable
          end
        end

        # Returns all of the possible paths (including partial variations)
        # to attempt to resolve with the given path.
        def possible_files(context, path, base_path)
          path      = Pathname.new(path)
          base_path = Pathname.new(base_path).dirname
          partial_path = partialize_path(path)
          additional_paths = [Pathname.new("#{path}.css"), Pathname.new("#{partial_path}.css"), Pathname.new("#{path}.css.#{syntax(path)}"), Pathname.new("#{partial_path}.css.#{syntax(path)}")]
          paths = additional_paths.concat([path, partial_path])

          if Sprockets::Sass::Utils.version_of_sprockets >= 3
            paths = additional_paths_for_sprockets(context, paths, path, base_path)
          end
          # Find base_path's root
          paths, root_path = add_root_to_possible_files(context, base_path, path, paths)
          [paths.compact, root_path]
        end

        def add_root_to_possible_files(context, base_path, path, paths)
          env_root_paths = context.environment.paths.map { |p| Pathname.new(p) }
          root_path = env_root_paths.find do |env_root_path|
            base_path.to_s.start_with?(env_root_path.to_s)
          end
          root_path ||= Pathname.new(context.root_path)
          # Add the relative path from the root, if necessary
          if path.relative? && base_path != root_path
            relative_path = base_path.relative_path_from(root_path).join path
            paths.unshift(relative_path, partialize_path(relative_path))
          end
          [paths, root_path]
        end

        def additional_paths_for_sprockets(context, paths, path, base_path)
          relatives = paths.map { |path_detected| path_detected.to_s.start_with?('.') ? Pathname.new(path_detected) : Pathname.new(path_detected.to_s.prepend('./')) }
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
          paths
        end

        # Returns the partialized version of the given path.
        # Returns nil if the path is already to a partial.
        def partialize_path(path)
          return unless path.basename.to_s !~ /\A_/
          Pathname.new path.to_s.sub(/([^\/]+)\Z/, '_\1')
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
          classes << Sprockets::SasscProcessor if defined?(Sprockets::SasscProcessor)
          classes << Sprockets::Preprocessors::DefaultSourceMap if defined?(Sprockets::Preprocessors::DefaultSourceMap)
          classes << Sprockets::SourceMapProcessor if defined?(Sprockets::SourceMapProcessor)
          classes
        end

        def content_type_of_path(context, path)
          if Sprockets::Sass::Utils.version_of_sprockets < 4
            attributes = context.environment.respond_to?(:attributes_for) ? context.environment.attributes_for(path) : context.environment.send(:parse_path_extnames, path.to_s)
            content_type = attributes.respond_to?(:content_type) ? attributes.content_type : attributes[1]
          else
            pathname = resolve_path(context, path)
            content_type = pathname.nil? ? nil : pathname.to_s.scan(/\?type\=(.*)/).flatten.first unless pathname.nil?
            attributes = {}
          end
          [content_type, attributes]
        end

        def build_input_for_process(context, path, data)
          content_type, _attributes = content_type_of_path(context, path)
          {
            environment: context.environment,
            cache: context.environment.cache,
            uri: path.to_s,
            filename: path.to_s,
            load_path: context.environment.paths,
            name: File.basename(path),
            content_type: content_type,
            data: data,
            metadata: context.metadata
          }
        end

        def check_path_before_process(path)
          return path if Sprockets::Sass::Utils.version_of_sprockets < 4
          asset = context.environment.load(path) # because resolve now returns file://
          asset.filename
        end

        def call_processor_input(processor, context, input, processors)
          result = processor.call(input)
          handle_process_result(context, result, processors)
        end

        def handle_complex_process_result(context, result, processors)
          data = result[:data] if result.key?(:data)
          context.metadata.merge!(result)
          context.metadata.delete(:data)
          if result.key?(:required)
            result[:required].each do |file|
              file_asset = context.environment.load(file)
              data += process(processors, context, file_asset.filename)
            end
          end
          data
        end

        def handle_process_result(context, result, processors)
          data = nil
          case result
          when NilClass
            # nothing - still nil
          when Hash
            data = handle_complex_process_result(context, result, processors)
          when String
            data = result
          else
            raise Error, "invalid processor return type: #{result.class}"
          end
          data
        end

        # Internal: Run processors on filename and data.
        #
        # Returns Hash.
        def process(processors, context, path)
          path = check_path_before_process(path)
          data = Sprockets::Sass::Utils.read_template_file(path.to_s)
          input = build_input_for_process(context, path, data)

          processors.each do |processor|
            data = call_processor_input(processor, context, input, processors)
          end

          data
        end

        def get_context_preprocessors(context, content_type)
          if Sprockets::Sass::Utils.version_of_sprockets >= 3
            context.environment.preprocessors[content_type].map { |a| a.class == Class ? a : a.class }
          else
            context.environment.preprocessors(content_type)
          end
        end

        def get_context_transformers(context, content_type, path)
          available_transformers = context.environment.respond_to?(:transformers) ? context.environment.transformers[content_type] : {}
          additional_transformers = available_transformers.key?(syntax_mime_type(path)) ? available_transformers[syntax_mime_type(path)] : []
          additional_transformers.is_a?(Array) ? additional_transformers : [additional_transformers]
        end

        def get_engines_from_attributes(attributes)
          attributes.respond_to?(:engines) ? attributes.engines : []
        end

        def get_all_processors_for_evaluate(context, content_type, attributes, path)
          engines = get_engines_from_attributes(attributes)
          preprocessors = get_context_preprocessors(context, content_type)
          additional_transformers = get_context_transformers(context, content_type, path)
          additional_transformers.reverse + preprocessors + engines.reverse
        end

        def filter_all_processors(processors)
          processors.delete_if do |processor|
            filtered_processor_classes.include?(processor) || filtered_processor_classes.any? do |filtered_processor|
              !processor.is_a?(Proc) && processor < filtered_processor
            end
          end
        end

        def evaluate_path_from_context(context, path, processors)
          if context.respond_to?(:evaluate)
            context.evaluate(path, processors: processors)
          else
            process(processors, context, path)
          end
        end

        # Returns the string to be passed to the Sass engine. We use
        # Sprockets to process the file, but we remove any Sass processors
        # because we need to let the Sass::Engine handle that.
        def evaluate(context, path)
          content_type, attributes = content_type_of_path(context, path)
          processors = get_all_processors_for_evaluate(context, content_type, attributes, path)
          filter_all_processors(processors)
          evaluate_path_from_context(context, path, processors)
        end
      end
    end
  end
end
