module Capable

  # This class is used to load the Capable.list on the repositories that have
  # code to be shared
  class ListParser
    extend Forwardable

    def_delegators :@cursors, :the, :file, :at, :provides, :depends, :on, :provides?, :file_for
    attr_reader :contents
    attr_reader :cursors

    # Create a new ListParser
    #
    # @param [String] contents the contents of the Capable.list file
    def initialize(contents)
      @cursors = CursorCollection.new
      @contents = contents
      @eval = false
    end

    # Eval the contents
    #
    # @return [CursorCollection] the cursor collection after evaluating the contents
    def evaluate!
      unless @eval
        @eval = true
        eval(@contents)
      end
      @cursors
    end

    # Check to make sure everything looks valid
    def check!
      evaluate!
      errors = @cursors.errors
      if errors.length > 0
        warn errors.join("\n")
        1
      else
        puts "No errors found!"
        0
      end
    end

    # For the rubyish definition
    def define(opts)
      cursor = @cursors.file
      cursor.at opts[:file]
      @cursors.the cursor
      provides = opts[:provides].is_a?(Array) ? opts[:provides] : [opts[:provides]]
      provides.compact.each do |provider|
        cursor.provides provider
      end
      depends = opts[:depends].is_a?(Array) ? opts[:depends] : [opts[:depends]]
      depends.compact.each do |dependency|
        cursor.depends cursor.on(dependency)
      end
      cursor
    end

  end

  class CursorCollection
    extend Forwardable
    def_delegators :check_cursor!, :at, :depends, :on
    def_delegators :@cursors, :length, :first, :[]
    attr_reader :cursors
    attr_reader :current_cursor

    class ProviderExists < Exception; end
    class NoCursor < Exception; end
    
    def initialize
      @cursors = []
      @current_cursor = nil
    end

    # Add a cursor to the collector
    #
    # @param [Cursor] cursor the cursor to add
    # @return [Cursor] the cursor you sent
    def add(cursor)
      @cursors << cursor unless @cursors.include?(cursor)
      cursor
    end

    # Checks if a provider with that name already exists
    #
    # @param [String] provider the provider name to check
    # @return [Cursor, nil] the cursor that already provided the name, or nil
    def provides?(provider)
      @cursors.find do |cursor|
        cursor.providers.include?(provider)
      end
    end

    # Changes the cursor
    #
    # @param [Cursor] cursor a cursor
    def the(cursor)
      @current_cursor = cursor
    end

    # Generates a file cursor and adds it to the cursor collection
    #
    # @param [String] file the file or pathname to add
    # @param [Array] provides what the file provides
    # @param [Array] depends what this depends on
    def file
      add FileCursor.new
    end

    # Makes sure we have a current cursor to work on, otherwise raise exception
    def check_cursor!
      @current_cursor or raise NoCursor.new("You have not defined anything to work with!")
    end

    # Adds a provider name to the current cursor if it doesn't already exist
    #
    # @param [String] provider the provider name/string to add
    def provides(provider, opts = {:raise_on_fail => true})
      if cursor = provides?(provider)
        raise ProviderExists.new("'#{provider}' is already provided by #{cursor}!") if opts[:raise_on_fail]
      else
        check_cursor!.provides(provider)
      end
    end

    # Checks that the stuff we have is valid on its own
    # Validity is confirmed by all listed dependencies existing in the providers
    # list and also the existence of all files.
    def errors
      errors = []
      all_providers = @cursors.collect {|cursor| cursor.providers }.flatten.compact.uniq
      @cursors.each do |cursor|
        errors << "#{cursor} is not valid!" unless cursor.valid?
        cursor.dependencies.each do |dep|
          errors << "#{cursor}'s dependency on '#{dep}' is not met. (#{dep} does not exist?)" unless all_providers.include?(dep)
        end
      end
      errors
    end

    # Get the filename for a provider name
    def file_for(provider)
      if cursor = provides?(provider)
        cursor.file.to_s
      else
        raise ProviderNotFound.new("The file for provider '#{provider}' is not found.")
      end
    end
    
  end

  class Cursor
    attr_reader :providers
    attr_reader :dependencies
    
    def initialize
      @providers = []
      @dependencies = []
    end

    # Adds a provider if it doesn't already exist on our list
    def provides(name)
      @providers << name unless @providers.include?(name)
    end

    # Adds a dependency if it doesn't already exist on our list
    def depends(name)
      @dependencies << name unless @dependencies.include?(name)
    end

    # A little helper for the dependencies
    def on(dep)
      dep
    end
  end

  class FileCursor < Cursor
    attr_reader :dependencies
    attr_reader :file
    
    def initialize
      @file = nil
      super
    end

    # Name the file that we are defining providers and dependencies on
    def at(x)
      @file = Pathname.new(x)
      provides @file.to_s
      @file
    end

    def to_s
      @file.to_s
    end

    def valid?
      File.exists? @file
    end

  end
end
