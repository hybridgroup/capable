module Capable

  # This class loads the Capable.load files at the places that downloaded code
  # from other repositories. The Capable.load tracks which version of the files
  # are currently used, and checks if they've changed based on their digests
  class LoadParser


    def initialize(contents)
      @contents = contents
      @manifest = YAML.load(contents)
      @eval = false
    end

    def check!
      errors = 0
      @manifest.each_pair do |source_key, files|
        files.each do |file|
          digest = file[Source::KeyName]
          target = file[:target]
          if File.exist?(target)
            current_digest = Source::KeyClass.new(File.read(target)).to_s
            if current_digest != digest
              errors += 1
              warn "#{target} has changed!"
            end
          else
            errors += 1
            warn "#{target} does not exist!"
          end
        end
      end
      puts "\n#{errors} Errors Found!"
      errors
    end

    def cleanup!
      @manifest.each_pair do |source_key, files|
        files.each do |file|
          Pathname.new(file[:target]).delete
        end
      end
      puts "Done."
      0
    end

    
  end

end
