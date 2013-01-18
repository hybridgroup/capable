module Capable

  # This is the source parser. It handles cloning repositories, generating files,
  # and everything needed for the Capable.load (namely generating sha2, marking
  # the location and ref)
  class SourceParser
  
    extend Forwardable
    def_delegators :@sources, :git

    def initialize(contents)
      @sources = SourceCollection.new
      @eval = false
      @contents = contents
    end

    def evaluate!
      unless @eval
        @eval = true
        eval(@contents)
      end
      @sources
    end

    def package!
      evaluate!
      @sources.package!
      0
    end
  end

  class SourceCollection
    class SourceExists < Exception; end
    attr_reader :sources
    
    def initialize
      @sources = {}
    end

    # Marks a new git source url and adds it to the source listing
    def git(source_url, opts = {:ref => :master, :base => 'vendor/capable/'}, &block)
      source_sha = Source::KeyClass.new(source_url).to_s
      if @sources[source_sha]
        raise SourceExists.new("The source '#{source_url}' has already been defined!")
      else
        @sources[source_sha] = GitSource.new(source_url, source_sha, opts, &block)
      end
    end

    # Fetches all the sources in this collection
    def fetch!
      @sources.each_pair do |key, source|
        source.fetch!
      end
    end

    # Attempt to load all noted files into memory (also serves as a check on the
    # whether the files exist and we have access to them)
    # TODO: Could be memory intensive if there are large files to be shared
    def get_files!
      @sources.each_pair do |key, source|
        source.get_files!
      end
    end

    # Attempt to save all files into their specified locations
    def save_files!
      @sources.each_pair do |key, source|
        source.save_files!
      end
    end

    # Packages
    def package!
      fetch!
      get_files!
      save_files!
      save_manifest!
      warn_about_missing_dependencies!
    end

    def save_manifest!
      manifest = @sources.reduce({}) do |m, ks|
        key, source = ks
        m[key] = source.manifest
        m
      end
      f = File.open('Capable.load', 'w')
      print "Writing the Capable.load manifest..."
      puts "#{f.write manifest.to_yaml}"
    end

    # List of all providers on capabilities in this source collection
    def providers
      @sources.collect do |key, source|
        source.providers
      end.flatten.uniq
    end

    def missing_dependencies
      dependencies - providers
    end

    # List of all dependencies on capabilities in this source collection
    def dependencies
      @sources.collect do |key, source|
        source.dependencies
      end.flatten.uniq
    end

    def warn_about_missing_dependencies!
      mdeps = missing_dependencies
      if mdeps.length > 0
        warn "There are missing dependencies! #{mdeps.length} of them listed below."
        warn "It looks like you need to add the following: #{mdeps.join("\n")}"
      end
    end
  end

  class Source
  
    KeyClass = OpenSSL::Digest::SHA256
    KeyName = :sha256

    class FileNotDirectory < Exception; end
    class SourceDownloadError < Exception; end
    class FileNotAvailable < Exception; end
    
    # Ensures that the directory exists
    #
    # @params [String] dir the directory to check
    # @params [Boolean] create whether to create the directory if it doesn't exsit
    def check_directory(dir, create = true)
      dir = Pathname.new(dir).expand_path
      if dir.exist? and dir.file?
        raise FileNotDirectory.new("Unexpected file at #{dir.to_s}")
      elsif create
        dir.mkpath
      else
        dir.exist?
      end
    end

    # Ensures the all the directories in the file's path exists
    def check_file_parents(file_path, create = true)
      dir = Pathname.new(file_path).expand_path.dirname
      check_directory(dir, create)
    end
  end

  class GitCapability
    extend Forwardable
    def_delegators :@source, :file_for, :git_show_file, :check_directory, :check_file_parents
    attr_reader :provider

    # Initialize a GitCapability
    def initialize(source, provider, options)
      @source = source
      @provider = provider
      @options = options
      @file = nil
    end

    # Load the file
    def get_file!
      @file ||= git_show_file(file_for(@provider), @options)
    end

    # The target location to save it in
    def target
      @options[:target] || File.join(@options[:base], @options[:subtarget] || file_for(@provider))
    end

    # Save the file to its targets
    def save_file!
      location = target
      check_file_parents(location)
      f = File.open(Pathname.new(location).expand_path, 'w')
      print "Writing to #{location}..."
      puts f.write(get_file!).to_s
      f.close
    end

    def manifest
      {:provider => @provider,
        Source::KeyName => Source::KeyClass.new(get_file!).to_s,
        :target => target}
    end

  end

  class GitSource < Source
    extend Forwardable
    def_delegators :listing, :cursors, :provides?, :file_for
  
    GIT_SOURCES_DIR = Pathname.new(ENV['CAPABLE_GIT_SOURCE_DIR'] ? ENV['CAPABLE_GIT_SOURCE_DIR'].dup : "~/.capable").expand_path.to_s.freeze
    GIT_ORIGIN = (ENV['CAPABLE_GIT_ORIGIN'] ? ENV['CAPABLE_GIT_ORIGIN'].dup : 'capable').freeze
    attr_reader :source_url
    attr_reader :capabilities

    # Creates a new GitSource. It sets up everything necessary for pulling from github
    #
    # @param [String] source_url the url of the git source to clone/fetch
    # @param [String] key the key that denotes the directory to store the repo
    # @param [Hash] opts extra options
    # @param [Proc] block code to eval immediately after initialization
    def initialize(source_url, key, opts = {}, &block)
      @source_url = source_url
      @source_key = key
      ref = if opts[:refname]
        "#{GIT_ORIGIN}/#{opts[:refname]}"
        else
        "#{GIT_ORIGIN}/master"
        end
      @options = {:ref => ref, :base => 'vendor/capable/'}.merge(opts)
      @capabilities = []
      @listing = nil
      @fetched = nil
      self.instance_eval(&block)
    end

    # Track the list of capabilities.
    # TODO: Setup this as a collection?
    def capable_of(provider, opts = {})
      @capabilities << GitCapability.new(self, provider, @options.merge(opts))
    end

    # Load all files in this source into memory
    def get_files!
      @capabilities.each(&:get_file!)
    end

    # Save all the files into directories
    def save_files!
      @capabilities.each(&:save_file!)
    end

    # Fetch the repository, and grab all the files and save
    def package!
      fetch!
      get_files!
      save_files!
    end

    # The Manifest hash for all the capabilities in this repository source
    def manifest
      @capabilities.collect(&:manifest)
    end

    # Get the listing info from the repository's Capable.list
    def listing
      if !@listing
        @listing = ListParser.new(git_show_file('Capable.list'))
        @listing.evaluate!
      end
      @listing
    end

    # Get the path of the source key
    def path
      @path ||= Pathname.new("#{GIT_SOURCES_DIR}/#{@source_key}")
    end

    # Get the full absolute path of the target directory (as a string)
    def expanded_path
      @expanded_path ||= path.expand_path
    end

    # The list of providers that our capabilities provide
    def providers
      @capabilities.collect do |cap|
        listing.provides?(cap.provider).providers
      end.flatten.uniq
    end

    # The list of dependencies that our capabilities need
    def dependencies
      @capabilities.collect do |cap|
        listing.provides?(cap.provider).dependencies
      end.flatten.uniq
    end

    # Get the contents of file on our ref
    def git_show_file(file, opts = nil)
      fetch!
      options = opts || @options
      
      Dir.chdir(expanded_path) do
        content = `git show '#{options[:ref]}':'#{file.gsub("'", "\\'")}'`
        if $?.success?
          content
        else
          warn "Unable to load file #{file} at #{options[:ref]}:\n"
          warn content
          raise FileNotAvailable.new("The file #{file} is not available on ref #{options[:ref]}")
        end
      end
      
    end

    # Fetch specified repository into the key subdirectory (if it doesn't exist
    # then clone it, otherwise just fetch latest refs)
    def fetch!
      if @fetched.nil? or @fetched < Time.now-300
        check_directory GIT_SOURCES_DIR
        
        Dir.chdir(GIT_SOURCES_DIR) do
          pid = if check_directory(path, false)
            puts "Already downloaded...Fetching latest updates for #{@source_url}"
            Process.spawn("git fetch #{GIT_ORIGIN}", :chdir => expanded_path)
          else
            # TODO: We may be able to do --no-checkout
            puts "Cloning latest data for #{@source_url}"
            Process.spawn("git clone --origin #{GIT_ORIGIN} '#{@source_url.gsub("'", "\\'")}' '#{@source_key}'")
          end
          status = Process.wait2(pid).last
          raise SourceDownloadError.new("Unable to download source at #{@source_url} (attempted to save at #{path})") unless status.success?
        end
        
        @fetched = Time.now
      end
    end
    
  end

end
