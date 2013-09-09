require 'snapback'
require 'snapback/cli/execute'
require 'snapback/cli/options'

module Snapback
  class CLI

    # The array of (unparsed) command-line options
    attr_reader :args

    # Save the args
    def initialize(args)
      @args = args.dup
    end


    # Mix-in the behavior
    include Execute, Options
  end
end