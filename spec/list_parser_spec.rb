require 'spec_helper'

describe "Capable.list Parsing" do
  describe "FileCursor" do
    before(:each) do
      @fc = Capable::FileCursor.new
    end
    it 'should be blank when initialized' do
      @fc.file.must_be_nil
      @fc.dependencies.must_be_empty
      @fc.providers.must_be_empty
    end

    it 'should be able to set the filename' do
      @fc.at("lib/test.rb")
      @fc.file.must_equal Pathname.new "lib/test.rb"
      @fc.providers.first.must_equal "lib/test.rb"
    end

    it 'should be able to set what it provides' do
      @fc.provides("Test")
      @fc.providers.must_include "Test"
    end

    it 'should not be able to double set providers' do
      @fc.provides "Test"
      @fc.provides "Tester"
      @fc.provides "Test"
      @fc.providers.length.must_equal 2
    end

    it 'should be able to define dependencies' do
      @fc.depends @fc.on "Test"
      @fc.dependencies.must_include "Test"
    end

    it 'should not be able to doubleset dependencies' do
      @fc.depends @fc.on "Test"
      @fc.depends @fc.on "Hello"
      @fc.depends @fc.on "Test"
      @fc.dependencies.length.must_equal 2
    end

    it 'should be able to check for errors' do
      @fc.at('libby')
      @fc.valid?.must_equal false
      @fc.at('Gemfile')
      @fc.valid?.must_equal true
    end
  end

  describe "CursorCollection" do
    before(:each) do
      @cc = Capable::CursorCollection.new
    end

    it 'should have no cursors when intialized' do
      @cc.cursors.length.must_equal 0
      @cc.current_cursor.must_be_nil
    end

    it 'should be able to add a cursor' do
      fc = Capable::FileCursor.new
      @cc.add fc
      @cc.cursors.must_include fc
    end

    it 'should be able to check the cursor' do
      lambda { @cc.check_cursor! }.must_raise Capable::CursorCollection::NoCursor
    end

    it 'should not raise NoCursor if there is a cursor' do
      @cc.the @cc.file
      @cc.check_cursor!.must_be_kind_of Capable::FileCursor
    end

    describe "delegators" do
      before(:each) do
        @cc.the @fc = @cc.file
      end

      it 'should be able to set provider info' do
        @cc.provides 'Tester'
        @fc.providers.must_include 'Tester'
      end

      it 'should not be able to set a preset provider' do
        @cc.provides 'Tester'
        @cc.the fc = @cc.file
        lambda { @cc.provides 'Tester' }.must_raise Capable::CursorCollection::ProviderExists
      end

      it 'should be able to set dependency info' do
        @cc.depends 'Hello'
        @fc.dependencies.must_include 'Hello'
      end

      it 'should not be able to double set the same dependency' do
        @cc.depends 'Hello'
        @fc.dependencies.must_include 'Hello'
        @cc.depends 'Tester'
        @fc.dependencies.must_include 'Tester'
        @fc.dependencies.length.must_equal 2
        @cc.depends 'Tester'
        @fc.dependencies.length.must_equal 2
      end

      it 'should be able to get the filename from a provider name' do
        @fc.at('lib/hello.rb')
        @fc.provides('Hey')
        @cc.file_for('Hey').must_equal 'lib/hello.rb'
      end
    end
  end

  describe "ListParser" do
    it 'should be able to initialize from config' do
      lp = Capable::ListParser.new("the file\n  at('lib/hello.rb')\n  depends on('Newbie')\n")
      lp.cursors.length.must_equal 0
      lp.evaluate!
      lp.cursors.length.must_equal 1
      lp.cursors.first.to_s.must_equal "lib/hello.rb"
      lp.cursors.first.dependencies.must_include 'Newbie'
    end

    it 'should be able to initialize from define config' do
      lp = Capable::ListParser.new("define(:file => 'lib/hello.rb', :depends => 'Newbie')")
      lp.cursors.length.must_equal 0
      lp.evaluate!
      lp.cursors.length.must_equal 1
      lp.cursors.first.to_s.must_equal "lib/hello.rb"
      lp.cursors.first.dependencies.must_include 'Newbie'
    end

    it 'should be able to check' do
      lp = Capable::ListParser.new("the file\n  at('Gemfile')")
      out, err = capture_io do
        lp.check!.must_equal 0
      end
      out.must_match(/No errors/)
    end
  end
end
