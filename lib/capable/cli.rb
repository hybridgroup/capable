require File.join File.dirname(__FILE__), '..', 'capable'

module Capable

  # Base class for all CLI utilities
  
  class CLI
    
    class CommandExists < Exception; end
    @commands = [:package, :check_status, :check_list, :help].freeze

    # Verifies if a command is a valid CLI command
    #
    # @param [String or Symbol] cmd the command to check
    def self.command?(cmd)
      @commands.include?(cmd.to_sym)
    end

    def initialize(argv = nil)
      @argv = argv || ARGV.dup
    end

    # Start the execution of the command given
    def start
      cmd = @argv[0]
      if cmd.nil? or cmd.empty? or !self.class.command?(cmd)
        warn "The command '#{cmd}' is an invalid command\n"
        help
        1
      else
        send cmd
      end
    end

    # Output help information
    def help
      puts "Valid Commands:\n"
      help_output :help, 'Output this help page'
      help_output :package, 'Load the Capable file and update files'
      help_output :verify, 'Verify that no files have changed since the last package'
      help_output :check_list, 'Check that our Capable.list is valid'
      0
    end

    # Helper method to output help information
    #
    # @param [String] cmd the command
    # @param [String] desc the description of the command
    def help_output(cmd, desc)
      puts "\t#{cmd}#{' '*(15-cmd.to_s.length)}#{desc}"
    end

    # Load the Capable file and update files
    # This will attempt to first run check_status that the files haven't changed since the
    # last packaging. It will fail if any file has changed.
    #
    # 
    def package
      file = @argv[1] || 'Capable'
      if File.exists?(file)
        contents = File.read(file)
        SourceParser.new(contents).package!
      else
        warn "File '#{file}' does not exist! Unable to load list..."
        1
      end
    end

    # Verify that no files have changed since the last package
    def check_status
      file = @argv[1] || 'Capable.load'
      if File.exists?(file)
        contents = File.read(file)
        LoadParser.new(contents).check!
      else
        warn "File '#{file}' does not exist! Unable to load list..."
        1
      end
    end

    # Check that our Capable.list is valid
    # Validity is confirmed by existence of all files listed
    def check_list
      file = @argv[1] || 'Capable.list'
      if File.exists?(file)
        contents = File.read(file)
        ListParser.new(contents).check!
        0
      else
        warn "File '#{file}' does not exist! Unable to load list..."
        1
      end
    end
  
  end
end


