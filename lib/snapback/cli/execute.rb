# require 'snapback/configuration'

require 'snapback/options'
require 'snapback/transaction'
require 'snapback/database'
require 'snapback/dsl'

module Snapback
  class CLI
    module Execute
      def self.included(base) #:nodoc:
        base.extend(ClassMethods)
      end

      module ClassMethods
        # Invoke snapback using the ARGV array as the option parameters. This
        # is what the command-line snapback utility does.
        def execute
          # Ensure user is root
          if Process.uid != 0 then
            $stderr.puts "#{"Must run as root".colorize(:red)}"
            exit 1
          end

          parse(ARGV).execute!
        end
      end

      def execute!
        begin
          case options[:command]
          when "install"
            require "snapback/app/install"
            Snapback::App::Install.instance.go

            puts ""
            exit
          end

          begin
            # Read confirmation options
            $config = YAML.load_file(options[:config])
          rescue
            raise "Could not load configuration file: #{options[:config]}"
          end

          # Connect to MySQL
          $database = Snapback::Database.instance
          $database.hostname = $config['mysql']['hostname']
          $database.username = $config['mysql']['username']
          $database.password = $config['mysql']['password']
          $database.connect

          case options[:command]
          when "create"
            require "snapback/app/create"
            Snapback::App::Create.instance.go
          when "snapshot"
            require "snapback/app/snapshot"
            Snapback::App::Snapshot.instance.go
          when "commit"
            require "snapback/app/commit"
            Snapback::App::Commit.instance.go
          when "rollback"
            require "snapback/app/rollback"
            Snapback::App::Rollback.instance.go
          when "drop"
            require "snapback/app/drop"
            Snapback::App::Drop.instance.go
          when "mount"
            require "snapback/app/mount"
            Snapback::App::Mount.instance.go
          when "unmount"
            require "snapback/app/unmount"
            Snapback::App::Unmount.instance.go
          end
        rescue
          puts ""
          $stderr.puts "#{$!.to_s.colorize(:red)}"
          puts "Use -v (--verbose) to view entire process".colorize(:red) if !options[:verbose]
          puts "Rolling back".colorize(:red)
          puts ""

          Snapback::Transaction.instance.do_rollback
        end

        puts ""
      end
    end
  end
end