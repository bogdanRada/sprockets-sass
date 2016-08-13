# frozen_string_literal: true
module Sprockets
  module Sass
    # Preprocessor for SCSS files
    class ScssTemplate < SassTemplate
      # Define the expected syntax for the template
      def self.syntax
        :scss
      end
    end
  end
end
