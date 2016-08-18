require 'sprockets'
require 'sprockets-sass'
require 'sprockets-helpers'
require 'compass'
require 'test_construct'

Compass.configuration do |compass|
  compass.line_comments = false
  compass.output_style  = :nested
end

# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each { |f| require f }

RSpec.configure do |config|
  config.include TestConstruct::Helpers
end


def write_asset(filename, contents, mtime = nil)
  mtime ||= [Time.now.to_i, File.stat(filename).mtime.to_i].max + 1
  File.open(filename, 'w') do |f|
    f.write(contents)
  end
  File.utime(mtime, mtime, filename)
end
