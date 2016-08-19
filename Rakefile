require 'bundler/setup'
require 'bundler/gem_tasks'
require 'appraisal'
require 'rspec/core/rake_task'


RSpec::Core::RakeTask.new(:spec) do |spec|
  spec.rspec_opts = ['--backtrace '] if ENV['DEBUG']
  spec.verbose = true
end

desc 'Default: run the unit tests.'
task default: [:all]

desc 'Test the plugin under all supported versions.'
task :all do |_t|
  if ENV['TRAVIS']
    if ENV['BUNDLE_GEMFILE'] =~ /gemfiles/ # Useful when using matrix in travis.yml
      appraisal_name = ENV['BUNDLE_GEMFILE'].scan(/(.*)\.gemfile/).flatten.first
      command_prefix = "appraisal #{appraisal_name}"
      exec ("#{command_prefix} bundle install && #{command_prefix} bundle exec rspec ")
    else
      exec(' bundle exec appraisal install && bundle exec rake appraisal spec')
   end
  else
    exec('bundle exec appraisal install && bundle exec rake appraisal spec')
  end
end
