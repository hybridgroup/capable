# Capable - the capability manager

Often times we need to reuse code between projects and it's too troublesome to properly split those parts into gems. It would be so much easier to just copy the file over! ... but then there's the problem with handling the changes...

This is primarily used for sharing models (and somewhat limitedly views) across similar subprojects. They usually act on the same schema. See the Appendix for problems this gem is trying to solve.

# Usage

You'll need to include capable as a development gem. (There's no reason to use it in production.)

## Defining your list

On your big-monolithic-app project, you should have a Capable.list file in its root with a definition of what you're going to provide. Basically a list of files you want to share with some data about it.

Capable.list
    
    the file
      at("lib/tutorial.rb")
      provides('Newbie')

    the file
      at("lib/hello.rb")
      depends
        on('Newbie')
      # no provides defaults to providing the filename, in this case, provides('lib/hello.rb')

    # You can also do the rubyish way if you prefer
    define(:file => "lib/world.rb", :provides => "world", :depends => "lib/hello.rb")


This system affords you some flexibility since the projects that actually need breaking up will still have the broken up parts at its core. Once the broken up parts have been fully cut off and reused in separate sub-projects, you can turn this into a storage repo for the shared code.

This is how I would recommend going about splitting up a project into multiple subprojects by the way. Not the part about letting it get big and monolithic, but the part about getting to the point of needing to split up the project. If you start out by building multiple subprojects to do different things, their architectures may not align and you end up trying to align multiple designs together rather than having a central design that gets shared.


## requiring files

Create a Capable file on the project head. This defines the source and manifests.

    git("git@github.com:somecompany/big-monolithic-app.git", :ref => :master, :base => "lib/") do
      capable_of "Newbie"
      capable_of "lib/hello.rb"
      capable_of "world"
    end

Then run:

    capable load

And you'll end up with three new files in your lib directory:

    tutorial.rb
    hello.rb
    world.rb


# Notes

These can be any type of file, but it was created with module/class loading in mind.

Modules should not depend on other modules. There is some dependency management, but it shouldn't be relied upon. Dependencies should be shaved down to the minimal.

Notice how the Capable.list looks like it's english? There's an elegance to it that I like. But we have to remember that this is code and you're not writing a sentence--if you try, it'll actually break because the ruby parser isn't an english parser. Think of it as though it's a poem rather than prose. You're writing poetry.

# TODO

Different types of storage other than git. eg. download from http, output from running an application or a ruby block, etc. Will add as needed, looks like it's good enough for now.
