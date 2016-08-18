require 'rubygems'
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

# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each { |f| require f }

RSpec.configure do |config|
  config.include TestConstruct::Helpers
end

def compile_asset_and_return_compilation(env, public_dir, filename )
  if Sprockets::Sass.version_of_sprockets < 3
    manifest = Sprockets::Manifest.new(env, public_dir)
  else
    manifest = Sprockets::Manifest.new(env, public_dir, 'manifest.json')
  end
  manifest.compile(filename)
  res = File.read(File.join(public_dir, manifest.files.keys.first))
  manifest.clobber
  res
end

def write_asset(filename, contents, mtime = nil)
  mtime ||= [Time.now.to_i, File.stat(filename).mtime.to_i].max + 1
  File.open(filename, 'w') do |f|
    f.write(contents)
  end
  if Sprockets::Sass.version_of_sprockets >= 3
    File.utime(mtime, mtime, filename)
  else
    mtime = Time.now + 1
    filename.utime mtime, mtime
  end
end
