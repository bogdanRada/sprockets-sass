# frozen_string_literal: true
require_relative '../v3/importer'
module Sprockets
  module Sass
    module V4
      # class used for importing files from SCCS and SASS files
      class Importer < Sprockets::Sass::V3::Importer

       def reverse_syntax(path)
         path.to_s.include?('.sass') ? :scss : :sass
       end

        def engine_from_glob(glob, base_path, options)
          context = options[:custom][:sprockets_context]
          env_root_paths = context_load_pathnames(context)
          root_path = env_root_paths.find do |env_root_path|
            base_path.to_s.start_with?(env_root_path.to_s)
          end
          root_path ||= context_root_path(context)
          engine_imports = resolve_glob(context, glob, base_path).reduce(''.dup) do |imports, path|
            context.depend_on path[:file_url]
            begin
            relative_path = Pathname.new(path[:path]).relative_path_from root_path
          rescue => e
            raise [e, Pathname.new(base_path).relative_path_from(root_path.dirname.parent) ,  imports, path, base_path, root_path].inspect
          end
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

        # Create a Sass::Engine from the given path.
        def engine_from_path(path, base_path, options)
          context = options[:custom][:sprockets_context]
          base_path = check_path_before_process(context, base_path)
          super(path, base_path, options)
        end


        # Finds all of the assets using the given glob.
        def resolve_glob(context, glob, base_path)
          base_path      = Pathname.new(base_path)
          path_with_glob = base_path.dirname.join(glob).to_s

          glob_files = Pathname.glob(path_with_glob).sort.reduce([]) do |imports, path|
            pathname = resolve(context, path, base_path)
            asset_requirable = asset_requirable?(context, pathname)
            imports << { file_url: pathname, path: path } if path != context.filename && asset_requirable
          end
          glob_files
        end

        def possible_files(context, path, base_path)
            path      = Pathname.new(path)
            base_path = Pathname.new(base_path).dirname
            partial_path = partialize_path(path)
            additional_paths = [Pathname.new("#{path}.css"), Pathname.new("#{partial_path}.css"), Pathname.new("#{path}.css.#{syntax(path)}"), Pathname.new("#{partial_path}.css.#{syntax(path)}")]
            additional_paths.concat([Pathname.new("#{path}.css"), Pathname.new("#{partial_path}.css"), Pathname.new("#{path}.css.#{reverse_syntax(path)}"), Pathname.new("#{partial_path}.css.#{reverse_syntax(path)}")])
            paths = additional_paths.concat([path, partial_path])

            # Find base_path's root
            paths, root_path = add_root_to_possible_files(context, base_path, path, paths)
            paths = additional_paths_for_sprockets(context, paths, path, base_path)
            paths = paths.uniq
            [paths.compact, root_path]
          end


        def check_path_before_process(context, path, a = nil)
          if path.to_s.start_with?('file://')
        #  path = Pathname.new(path.to_s.gsub(/\?type\=(.*)/, "?type=text/#{syntax(path)}"))  # @TODO : investigate why sometimes file:/// URLS are ending in ?type=text instead of ?type=text/scss
            asset = context.environment.load(path) # because resolve now returns file://
            asset.filename
          else
            path
          end
        end

        def stat_of_pathname(context, pathname, _path)
          filename = check_path_before_process(context, pathname)
          context.environment.stat(filename)
        end

        # @TODO find better alternative than scanning file:// string for mime type
        def content_type_of_path(context, path)
          pathname = context.resolve(path)
          content_type = pathname.nil? ? nil : pathname.to_s.scan(/\?type\=(.*)/).flatten.first unless pathname.nil?
          attributes = {}
          [content_type, attributes]
        end

        def get_context_transformers(context, content_type, path)
          available_transformers =  context.environment.transformers[content_type]
          additional_transformers = available_transformers.key?(syntax_mime_type(path)) ? available_transformers[syntax_mime_type(path)] : []
          additional_transformers.is_a?(Array) ? additional_transformers : [additional_transformers]
          css_transformers = available_transformers.key?('text/css') ? available_transformers['text/css'] : []
          css_transformers = css_transformers.is_a?(Array) ? css_transformers : [css_transformers]
          additional_transformers = additional_transformers.concat(css_transformers)
          additional_transformers
        end

        def filter_all_processors(processors)
          processors.delete_if do |processor|
            filtered_processor_classes.include?(processor) || filtered_processor_classes.any? do |filtered_processor|
              !processor.is_a?(Proc) && ((processor.class != Class && processor.class < filtered_processor) || (processor.class == Class && processor < filtered_processor))
            end
          end
        end

        def call_processor_input(processor, context, input, processors)
          if processor.respond_to?(:processors)
            processor.processors = filter_all_processors(processor.processors)
          end
          super(processor, context, input, processors)
        end

        def filtered_processor_classes
          classes = super
          classes << Sprockets::SassCompressor if defined?(Sprockets::SassCompressor)
          classes << Sprockets::SasscCompressor if defined?(Sprockets::SasscCompressor)
          classes << Sprockets::YUICompressor if defined?(Sprockets::YUICompressor)
          classes
        end
      end
    end
  end
end
