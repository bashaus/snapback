require "lvm"
require "singleton"

module Blanketdb
  module App
    class Install
      include Singleton

      def go
        puts ""
        puts "Hi!"
        puts ""
        puts "I'm going to guide you through setting up Blanketdb."
        puts "This script will check to see if your environment can run "
        puts "Blanketdb and will setup configuration files for you."
        puts ""

        begin
          run "Checking LVM is installed",
            "lvm version"
        rescue
          raise "You must install LVM before you can use this application"
        end

        # Get information from LVM
        lvm = LVM::LVM.new({:command => "sudo lvm", :version => "2.02.30"})
        volume_groups = []
        volume_group = nil

        lvm.volume_groups.each do |vg|
          volume_groups.push(vg)
        end
        puts ""

        # Decide which Logical volume use to use
        if volume_groups.size == 0 then
          raise "You do not have any volume groups in LVM. Please setup LVM before using Blanketdb"
        elsif volume_groups.size == 1 then
          volume_group = volume_groups[0];
          puts "You have one volume group named #{volume_group.name.green}."
          puts "Blanketdb will use this logical volume."
        else
          puts "Here is a list of volume groups on your system:"

          volume_groups.each do |vg|
            puts "#{volume_groups.size}.\t#{vg.name}"
          end

          volume_group_number = ask_int "Which volume group would you like Blanketdb use", volume_groups.size
          volume_group = volume_groups[volume_group_number - 1];
        end

        puts ""

        # Check for mount directory
        mysql_mount_dir = ask_string "Where do you want to mount your logical volumes [/mnt/mysql]"
        puts ""

        if mysql_mount_dir.empty? then
          mysql_mount_dir = "/mnt/mysql"
        end

        if !check "Checking for directory #{mysql_mount_dir}", lambda {
          File.directory? mysql_mount_dir
        } then
          run "Creating directory #{mysql_mount_dir}",
            "mkdir -p #{mysql_mount_dir}"

          on_rollback lambda {
            run "Removing #{mysql_mount_dir} directory",
              "rm -rf #{mysql_mount_dir}"
          }
        end

        # MySQL connection

        while true
          puts ""
          puts "Enter the crudentials to connect to MySQL"

          $database = Blanketdb::Database.instance

          $database.hostname = ask_string "MySQL hostname [localhost]"
          if $database.hostname.empty? then
            $database.hostname = "localhost"
          end

          $database.username = ask_string "MySQL username [root]"
          if $database.username.empty? then
            $database.username = "root"
          end

          $database.password = ask_string "MySQL password"

          puts ""

          begin
            check "Connecting to MySQL database", lambda {
              $database.connect
              true
            }
          rescue
            show_failed
            next
          end

          break
        end

        if !check "Checking #{"innodb_file_per_table"} is #{"ON"}", lambda {
          $database.innodb_file_per_table
        } then
          debug "Setting #{"innodb_file_per_table"} to #{"ON"}"
          $database.set_innodb_file_per_table true

          on_rollback lambda {
            debug "Setting #{"innodb_file_per_table"} to #{"OFF"}"
            $database.set_innodb_file_per_table false
          }
        end

        $config = {
          'lvm' => {
              'volume_group'    => volume_group.name.to_s,
              'prefix_database' => 'blanketdb-active',
              'prefix_backup'   => 'blanketdb-backup'
          },

          'mysql' => {
              'hostname'        => $database.hostname,
              'username'        => $database.username,
              'password'        => $database.password
          },

          'filesystem' => {
              'mount'           => '/mnt/mysql'
          }
        }

        File.open("config/blanketdb.yml", 'w+') { |f|
          f.write($config.to_yaml)
        }

        on_rollback lambda {
          File.unlink "config/blanketdb.yml"
        }

        puts ""
        puts "Blanketdb is now installed and configured."
        puts "To start using Blanketdb, run the following command: "
        puts ""
        puts "sudo ./blanketdb --help".yellow
      end
    end
  end
end