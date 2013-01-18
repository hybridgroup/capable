require 'spec_helper'
require 'capable/cli'

describe Capable::CLI do

  describe "#help" do
    it 'should output help when asked' do
      cli = Capable::CLI.new %w(help)
      out, err = capture_io do
        cli.start.must_equal 0
      end
      out.must_match(/Valid Commands/)
    end

    it 'should output help when command is unrecognized' do
      cli = Capable::CLI.new %w(etuhateuh)
      out, err = capture_io do
        cli.start.must_equal 1
      end
      out.must_match(/Valid Commands/)
      err.must_match(/invalid command/)
    end
  end

  describe "#package" do
    it 'should be able to package' do
      clean_target_dir
      jump_to('target_files') do
        cap_content = %q|
        git("file://#{test_content_dirs('list_files')}", :refname => 'master') do
          capable_of "world"
          capable_of "lib/hello.rb", :target => 'hello_you.rb'
          capable_of "Newbie"
        end|
        f = File.open('Capable', 'w')
        f.write cap_content
        f.close
        cli = Capable::CLI.new %w(package)
        out, err = capture_io do
          cli.start.must_equal 0
        end
      end
      
    end
  end

  describe "#verify" do
    it 'should be able to verify packages are correct' do
      jump_to('load_files') do
        cli = Capable::CLI.new %w(verify)
        out, err = capture_io do
          cli.start.must_equal 0
        end
        out.must_match(/0 Errors/)
        err.must_be_empty
      end

    end

    it 'should be able to verify packages are changed' do
      jump_to('load_files_error') do
        cli = Capable::CLI.new %w(verify)
        out, err = capture_io do
          cli.start.must_equal 3
        end
        out.must_match(/3 Errors/)
        err.must_match(/changed/)
      end
    end
  end


  describe "#check_list" do
    it 'should be able to check the list' do
      jump_to('list_files') do
        cli = Capable::CLI.new %w(check_list)
        out, err = capture_io do
          cli.start.must_equal 0
        end
        out.must_match(/No errors/)
      end
    end
  end

  describe "#cleanup" do
    it 'should be able to remove created files' do
      jump_to('target_files') do
        `cp -r ../load_files/* ./`
        cli = Capable::CLI.new %w(cleanup)
        out, err = capture_io do
          cli.start.must_equal 0
        end
        Dir.glob('*').wont_include("hello_you.rb")
      end
    end
  end

end
