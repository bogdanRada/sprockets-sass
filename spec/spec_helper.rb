require 'sprockets'
require 'sprockets-sass'
require 'sprockets-helpers'
require 'compass'
require 'test_construct'

Compass.configuration do |compass|
  compass.line_comments = false
  compass.output_style  = :nested
end


TestConstruct::PathnameExtensions.class_eval do
  alias_method :original_destroy!, :destroy!

  def destroy!
    # nothing
  end

end

# def nested_css_sprockets3(line)
#   new_line = Sprockets.respond_to?(:register_transformer) ? line.gsub(/(\n[[:space:]]+)+/, ' ') : line
#   new_line
# end

# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each { |f| require f }

RSpec.configure do |config|
  config.include TestConstruct::Helpers
end
