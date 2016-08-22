module Sprockets
  module Sass
    module V2
    class ScssTemplate < Sprockets::Sass::V2::SassTemplate
      self.default_mime_type = 'text/css'

      # Define the expected syntax for the template
      def syntax
        :scss
      end
    end
    end
  end
end
