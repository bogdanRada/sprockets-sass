module Sprockets
  module Sass
    class  Utils
      class << self

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
