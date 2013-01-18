$:.unshift File.expand_path('..', __FILE__)
$:.unshift File.expand_path('../../lib', __FILE__)

require 'minitest/autorun'
require 'minitest/spec'
require 'minitest/mock'

ENV['CAPABLE_GIT_ORIGIN'] ||= 'capable-test'
ENV['CAPABLE_GIT_SOURCE_DIR'] ||= '~/.capable-test'

START_PWD = File.absolute_path Dir.pwd


# Execute the given block inside path
#
# @param [String] path the path to execute in (assuming relative path from this)
# @param [Proc] block the block to run
def jump_to(path, &block)
  Dir.chdir(test_content_dirs(path), &block)
end

def test_content_dirs(path)
  File.expand_path(File.dirname(__FILE__) + '/' + path)
end

def clean_git_source_dir
  `rm -rf #{Capable::GitSource::GIT_SOURCES_DIR}`
end

def clean_target_dir
  `rm -rf #{test_content_dirs('target_files')}`
  `mkdir #{test_content_dirs('target_files')}`
end



require 'capable'
