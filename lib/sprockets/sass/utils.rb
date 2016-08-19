# frozen_string_literal: true
module Sprockets
  module Sass
    class Utils
      class << self
        def read_file_binary(file, options = {})
          default_encoding = options.delete :default_encoding

          # load template data and prepare (uses binread to avoid encoding issues)
          data = read_template_file(file)

          if data.respond_to?(:force_encoding)
            if default_encoding
              data = data.dup if data.frozen?
              data.force_encoding(default_encoding)
            end

            unless data.valid_encoding?
              raise Encoding::InvalidByteSequenceError, "#{filename} is not valid #{data.encoding}"
            end
          end
          data
        end

        def digest(options)
          options.delete_if { |_key, value| value.is_a?(Pathname) } if options.is_a?(Hash)
          options = options.to_s unless options.is_a?(Hash)
          if defined?(Sprockets::DigestUtils)
            Sprockets::DigestUtils.digest(options)
          else
            options = options.is_a?(Hash) ? options : { value: options }
            Digest::SHA256.hexdigest(JSON.generate(options))
          end
        end

        def read_template_file(file)
          data = File.open(file, 'rb', &:read)
          if data.respond_to?(:force_encoding)
            # Set it to the default external (without verifying)
            data.force_encoding(Encoding.default_external) if Encoding.default_external
          end
          data
        end

        def module_include(base, mod)
          old_methods = {}

          mod.instance_methods.each do |sym|
            old_methods[sym] = base.instance_method(sym) if base.method_defined?(sym)
          end

          mod.instance_methods.each do |sym|
            method = mod.instance_method(sym)
            base.send(:define_method, sym, method)
          end

          yield
        ensure
          mod.instance_methods.each do |sym|
            base.send(:undef_method, sym) if base.method_defined?(sym)
          end
          old_methods.each do |sym, method|
            base.send(:define_method, sym, method)
          end
        end
      end
    end
  end
end
