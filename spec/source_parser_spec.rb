require 'spec_helper'

describe "Capable Parsing" do

  describe "GitSource" do
    it 'should be able to initialize and load a git source' do
      clean_git_source_dir
      out, err = capture_io do
        gs = Capable::GitSource.new("file://" + test_content_dirs("list_files"), "test") do
          capable_of "Newbie"
        end
        gs.listing.cursors.length.must_equal 3
        gs.capabilities.length.must_equal 1
      end
      out.must_match(/Cloning/)
    end

    it 'should be able to get the target path and expanded_path' do
      gs = Capable::GitSource.new("file://" + test_content_dirs("list_files"), "testkey") do
        capable_of "Newbie"
      end
      gs.path.must_be_kind_of(Pathname)
      gs.path.to_s.must_match(/testkey/)
      gs.expanded_path.to_s.must_match(/^\//)
    end

    it 'should be able to load files and save' do
      clean_target_dir
      gs = Capable::GitSource.new("file://" + test_content_dirs("list_files"), "test") do
        capable_of "Newbie", :target => test_content_dirs("target_files/x/y/hello.rb")
      end
      out, err = capture_io do
        gs.fetch!
        gs.git_show_file('lib/hello.rb').must_include('Hello')
        gs.get_files!
        gs.save_files!
      end
      out.must_match(/(Fetching|Cloning)/)
      out.must_match(/Writing to/)
    end

    it 'should not be able to load files that do not exist' do
      gs = Capable::GitSource.new("file://" + test_content_dirs("list_files"), "test", {:base => test_content_dirs('target_files')}) do
        capable_of "Newbie"
      end
      out, err = capture_io do
        gs.fetch!
      end
      out.must_match(/(Fetching|Cloning)/)
      lambda { gs.git_show_file('tehth') }.must_raise(Capable::Source::FileNotAvailable)
    end

    it 'should be able to package' do
      clean_target_dir
      jump_to('target_files') do
        gs = Capable::GitSource.new("file://" + test_content_dirs("list_files"), "test", {:base => test_content_dirs('target_files')}) do
          capable_of "Newbie"
        end
        out, err = capture_io do
          gs.package!
        end
        out.must_match(/(Fetching|Cloning)/)
        out.must_match(/Writing to/)
      end
    end

    it 'should be able to get the providers list' do
      gs = Capable::GitSource.new("file://" + test_content_dirs("list_files"), "test", {:base => test_content_dirs('target_files')}) do
        capable_of "Newbie"
      end
      out, err = capture_io do
        gs.fetch!
      end
      gs.providers.length.must_equal 2
      gs.providers.must_include "Newbie"
    end

    it 'should be able to get the dependencies list' do
      gs = Capable::GitSource.new("file://" + test_content_dirs("list_files"), "test", {:base => test_content_dirs('target_files')}) do
        capable_of "lib/hello.rb"
      end
      out, err = capture_io do
        gs.fetch!
      end
      gs.dependencies.length.must_equal 1
      gs.dependencies.must_include "Newbie"
    end
  end

  describe "GitCapability" do
    it 'should have tests that are real'
    # Skimping out on this since the GitSource is the core of it
    # But I should add tests for error/edge cases
  end

  describe "SourceCollection" do
    it 'should be able to initialize with blank sources' do
      Capable::SourceCollection.new.sources.length.must_equal 0
    end

    describe "exists" do
      before(:each) do
        @sc = Capable::SourceCollection.new
      end

      it 'should be able to add a git source' do
        @sc.git("file://" + test_content_dirs('list_files'), {:base => test_content_dirs('target_files')}) do
          capable_of "Newbie"
        end
        @sc.sources.length.must_equal 1
      end

      it 'should not be able to add the same git source twice' do
        @sc.git("file://" + test_content_dirs('list_files'), {:base => test_content_dirs('target_files')}) do
          capable_of "Newbie"
        end
        
        lambda do
          @sc.git("file://" + test_content_dirs('list_files')) do
            capable_of "Nothing"
          end
        end.must_raise(Capable::SourceCollection::SourceExists)
      end

      # TODO: split tests up into individual calls or add additional tests for them
      it 'should be able to package' do
        @sc.git("file://" + test_content_dirs('list_files'), {:base => test_content_dirs('target_files')}) do
          capable_of "lib/hello.rb"
        end
        out, err = capture_io do
          jump_to('target_files') do
            @sc.package!
          end
        end

        out.must_match(/Writing/)
        out.must_match(/Capable\.load/)
        err.must_match(/missing dependencies/)
        err.must_match(/1 of them/)
      end
      
    end
  end

  describe "SourceParser" do
    it 'should be able to package from a Capable file' do
      clean_target_dir
      cap_content = %q|
      git("file://#{test_content_dirs('list_files')}", :refname => 'master') do
        capable_of "world"
        capable_of "lib/hello.rb", :target => 'hello_you.rb'
        capable_of "Newbie"
      end|
      jump_to('target_files') do
        Dir.glob('*').must_be_empty
        sp = Capable::SourceParser.new(cap_content)
        out, err = capture_io do
          sp.package!
        end
        glob = Dir.glob('*')
        glob.must_include('hello_you.rb')
        glob.must_include('Capable.load')
        glob.must_include('vendor')
        vendor_glob = Dir.glob('vendor/capable/lib/*')
        vendor_glob.must_include("vendor/capable/lib/tutorial.rb")
        vendor_glob.must_include("vendor/capable/lib/world.rb")
      end

    end
  end

end
