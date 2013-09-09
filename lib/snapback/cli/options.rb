require 'optparse'

module Snapback
  class CLI
    module Options
      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        # Return a new CLI instance with the given arguments pre-parsed and
        # ready for execution.
        def parse(args)
          cli = new(args)
          cli.parse_options!
          cli
        end
      end

      # The hash of (parsed) command-line options
      attr_reader :options

      def option_parser
        @option_parser ||= OptionParser.new do |opts|
          opts.banner = "Usage: sudo snapback [command] [options]"

          opts.separator "Create database snapshots using logical volume management (LVM)"
          opts.separator ""
          opts.separator "Commands:"
          opts.separator "    install                   Check the environment is sane and setup"
          opts.separator "    create DBNAME -s SIZE     Create a new snapback compliant database"
          opts.separator "    snapshot DBNAME -s SIZE   Take a snapshot of the current position"
          opts.separator "    commit DBNAME             Commit the working copy"
          opts.separator "    rollback DBNAME           Rollback the working copy to the snapshot"
          opts.separator "    drop DBNAME               Drop an existing database"
          opts.separator "    mount DBNAME              Mount an existing database"
          opts.separator "    unmount DBNAME            Unmount an existing database"
          opts.separator ""
          opts.separator "Options:"

          opts.on("-s", "--size SIZE",
                  "Allocate a size parameter (e.g.: 1M, 1G)") do |q|
            options[:size] = q
          end

          opts.on("-v", "--verbose",
                  "Show detailed transaction information") do
            options[:verbose] = true
          end

          opts.on("-h", "--help",
                  "Show this help screen") do
            puts opts
            exit
          end

          opts.on("-c", "--config",
                  "Configuration file") do |q|
            options[:config] = q
          end

          opts.separator ""
        end
      end

      def parse_options!
        @options = {}
        options[:command]  = nil
        options[:database] = nil

        options[:config]  = "#{File.expand_path('~')}/.snapback.yml"
        options[:verbose] = false
        options[:size]    = nil

        opts = option_parser
        opts.parse!(args)

        case args[0]
        when "install", "create", "snapshot", "commit", "rollback", "drop", "mount", "unmount"
          options[:command] = args[0]
        when nil
          puts opts
          exit
        else
          $stderr.puts "command '#{args[0]}' not recognised"
          puts opts
          exit
        end

        case options[:command]
        when "create", "snapshot", "commit", "rollback", "drop", "mount", "unmount"
          if args[1].nil? then
            $stderr.puts "you must specify a database with command '#{options[:command]}'"
            puts opts
            exit
          end

          options[:database] = args[1]
        end
      end
    end
  end
end