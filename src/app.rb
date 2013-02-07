require "singleton"
require "open4"
require 'lvm'

module Blanketdb
  class App
    include Singleton

    LOCKED_FILES = ['.', '..', 'lost+found']

    def install

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

    def create
      # Ensure we have a size parameter
      if $options[:size].nil? then
        raise "You must specify a size attribute. E.g.: -s 500M"
      end

      volume_group_name = "#{$config['lvm']['volume_group']}"
      logical_volume_name = "#{$config['lvm']['prefix_database']}-#{$options[:database]}"
      mount_dir = get_mount_dir $options[:database]
      mysql_data_dir = $database.get_data_dir

      if !check "Checking database exists #{$options[:database]}", lambda {
        $database.db_exists?($options[:database])
      } then
        check "Creating database '#{$options[:database]}'", lambda {
          $database.db_create($options[:database])
        }
        
        on_rollback lambda {
          check "Database '#{$options[:database]}' is being dropped", lambda {
            $database.db_drop($options[:database])
          }
        }
      end

      exec_flush

      # Stop the MySQL Server
      $database.server_stop

      on_rollback lambda {
        $database.server_start
      }

      # Create a new logical volume (500MB)
      # lvcreate –L 500MB –n mysql-{dbName} {vgName};
      run "Create logical volume", 
        "lvcreate -L #{$options[:size]} -n #{logical_volume_name} #{volume_group_name}"

      on_rollback lambda {
        run "Removing logical volume",
          "lvremove -f /dev/#{volume_group_name}/#{logical_volume_name}"
      }

      # Format the logical volume in ext4 format
      # mkfs.ext4 /dev/{vgName}/mysql-{dbName};
      run "Format logical volume filesystem",
        "mkfs.ext4 /dev/#{volume_group_name}/#{logical_volume_name}"

      # Create a new directory for where the MySQL database can be mounted
      # mkdir /mnt/mysql/{dbName};

      if !File.directory? mount_dir then
        run "Make mount directory", 
          "mkdir #{mount_dir}"

        on_rollback lambda {
          run "Removing mount directory",
            "rmdir #{$mount_dir}"
        }

        run "Changing permissions of mount directory",
          "chmod 0777 #{mount_dir}"
      end
      
      # # Mount the new logical volume
      # mount /dev/{vgName}/mysql-{dbName} /mnt/mysql/{dbName};
      exec_mount "/dev/#{volume_group_name}/#{logical_volume_name}", mount_dir

      # # Move the contents of the database to the new logical volume
      # mv {mysql-data-dir}/{dbName}/* /mnt/mysql/{dbName};

      move_mysql_files "#{mysql_data_dir}/#{$options[:database]}", mount_dir

      on_rollback lambda {
        move_mysql_files mount_dir, "#{mysql_data_dir}/#{$options[:database]}"
      }

      # # Remove the folder in the MySQL data directory
      # rmdir {mysql-data-dir}/{dbName}/
      run "Remove mysql database directory",
        "rm -rf #{mysql_data_dir}/#{$options[:database]}"

      on_rollback lambda {
        run "Re-creating MySQL database directory",
          "mkdir #{mysql_data_dir}/#{$options[:database]}"

        exec_chown "#{mysql_data_dir}/#{$options[:database]}"
      }

      # # Symbolic-link the MySQL data directory to the new logical volume
      # ln -s /mnt/mysql/{dbName} {mysql-data-dir}/{dbName}/
      exec_link "#{mysql_data_dir}/#{$options[:database]}", mount_dir

      # # Change the permissions & ownership to MySQL 
      # chown -R mysql:mysql {mysql-data-dir}/{dbName}/
      # chown -R mysql:mysql /mnt/mysql/{dbName}/
      exec_chown "#{mysql_data_dir}/#{$options[:database]}"
      exec_chown mount_dir

      # Stop the MySQL Server
      $database.server_start

      on_rollback lambda {
        $database.server_stop
      }
    end

    def snapshot
      # Ensure we have a size parameter
      if $options[:size].nil? then
        raise "You must specify a size attribute. E.g.: -s 100M"
      end

      if !$database.db_exists?($options[:database]) then
        raise "Database '#{$options[:database]}' does not exist"
      end

      volume_group_name = "#{$config['lvm']['volume_group']}"
      logical_volume_name = "#{$config['lvm']['prefix_database']}-#{$options[:database]}"
      mount_dir = get_mount_dir $options[:database]
      mysql_data_dir = $database.get_data_dir

      # Flush the MySQL Logs
      exec_flush

      # Stop the MySQL Server
      $database.server_stop

      on_rollback lambda {
        $database.server_start
      }

      # Unlink
      exec_unlink "#{mysql_data_dir}/#{$options[:database]}", mount_dir

      # Unmount
      exec_unmount "/dev/#{volume_group_name}/#{logical_volume_name}", mount_dir

      # Deactivate
      exec_deactivate "/dev/#{volume_group_name}/#{logical_volume_name}"
      
      # Branch the logical volume with a snapshot
      run "Snapshot the logical volume",
        "lvcreate -L #{$options[:size]} -s -n #{$config['lvm']['prefix_backup']}-#{$options[:database]} /dev/#{volume_group_name}/#{logical_volume_name}"

      on_rollback lambda {
        run "Remove the snapshot",
          "lvremove /dev/#{volume_group_name}/#{$config['lvm']['prefix_backup']}-#{$options[:database]}"
      }

      # Active the master drive
      exec_activate "/dev/#{volume_group_name}/#{logical_volume_name}"

      # Mount the master drive
      exec_mount "/dev/#{volume_group_name}/#{logical_volume_name}", mount_dir

      # Symbolic-link the MySQL data directory to the new logical volume
      # ln -s /mnt/mysql/{dbName} {mysql-data-dir}/{dbName}/
      exec_link "#{mysql_data_dir}/#{$options[:database]}", mount_dir

      # Change the permissions & ownership to MySQL
      exec_chown "#{mysql_data_dir}/#{$options[:database]}"
      exec_chown mount_dir

      # Start the MySQL Server
      $database.server_start

      on_rollback lambda {
        $database.server_stop
      }
    end

    def rollback
      volume_group_name = "#{$config['lvm']['volume_group']}"
      logical_volume_name = "#{$config['lvm']['prefix_database']}-#{$options[:database]}"
      mount_dir = get_mount_dir $options[:database]
      mysql_data_dir = $database.get_data_dir

      # Flush the MySQL Logs
      exec_flush

      # Stop the MySQL Server
      $database.server_stop

      on_rollback lambda {
        $database.server_start
      }

      # Remove the symbolic link
      exec_unlink "#{mysql_data_dir}/#{$options[:database]}", mount_dir

      # Unmount the logical volume
      exec_unmount "/dev/#{volume_group_name}/#{logical_volume_name}", mount_dir

      # Deactivate the logical volume
      exec_deactivate "/dev/#{volume_group_name}/#{logical_volume_name}"

      # Merge the old logical volume into the new one
      # lvconvert --merge /dev/{vgName}/backup-{dbName}
      run "Merging the snapshot into the live logical volume",
        "lvconvert --merge /dev/#{volume_group_name}/#{$config['lvm']['prefix_backup']}-#{$options[:database]}"

      # Active the master drive
      # lvchange -ay /dev/{vgName}/mysql-{dbName}
      exec_activate "/dev/#{volume_group_name}/#{logical_volume_name}"

      # Mount the logical volume
      exec_mount "/dev/#{volume_group_name}/#{logical_volume_name}", mount_dir

      # Symbolic-link the MySQL data directory to the new logical volume
      exec_link "#{mysql_data_dir}/#{$options[:database]}", mount_dir

      # Change the permissions & ownership to MySQL 
      # chown -R mysql:mysql {mysql-data-dir}/{dbName}/
      # chown -R mysql:mysql /mnt/mysql/{dbName}/
      exec_chown "#{mysql_data_dir}/#{$options[:database]}"
      exec_chown "#{mount_dir}"

      # Start the MySQL Server
      $database.server_start

      on_rollback lambda {
        $database.server_stop
      }
    end

    def commit
      # Remove the backup
      # lvremove /dev/DEFAULT/backup-{dbName}
    end

    def drop
      volume_group_name = "#{$config['lvm']['volume_group']}"
      logical_volume_name = "#{$config['lvm']['prefix_database']}-#{$options[:database]}"
      mount_dir = get_mount_dir $options[:database]
      mysql_data_dir = $database.get_data_dir

      # Remove the backup
      self.commit

      if !$database.db_exists?($options[:database]) then
        raise "Database '#{$options[:database]}' does not exist"
      end

      # Flush
      exec_flush

      # Stop the MySQL Server
      $database.server_stop

      on_rollback lambda {
        $database.server_start
      }

      # Unlink
      exec_unlink "#{mysql_data_dir}/#{$options[:database]}", mount_dir

      # Unmount
      exec_unmount "/dev/#{volume_group_name}/#{logical_volume_name}", mount_dir

      # Remove logical volume
      run "Remove logical volume", 
        "lvremove -f /dev/#{volume_group_name}/#{logical_volume_name}"

      # Start the MySQL Server
      $database.server_start

      on_rollback lambda {
        $database.server_stop
      }
    end

    def mount
      volume_group_name = "#{$config['lvm']['volume_group']}"
      logical_volume_name = "#{$config['lvm']['prefix_database']}-#{$options[:database]}"
      mount_dir = get_mount_dir $options[:database]
      mysql_data_dir = $database.get_data_dir

      exec_flush

      # Stop the MySQL Server
      $database.server_stop

      on_rollback lambda {
        $database.server_start
      }

      # Create a new directory for where the MySQL database can be mounted
      # mkdir /mnt/mysql/{dbName};

      if !File.directory? mount_dir then
        run "Make mount directory", 
          "mkdir #{mount_dir}"

        on_rollback lambda {
          run "Removing mount directory",
            "rmdir #{$mount_dir}"
        }

        run "Changing permissions of mount directory",
          "chmod 0777 #{mount_dir}"
      end
      
      # # Mount the new logical volume
      # mount /dev/{vgName}/mysql-{dbName} /mnt/mysql/{dbName};
      exec_mount "/dev/#{volume_group_name}/#{logical_volume_name}", mount_dir

      # # Symbolic-link the MySQL data directory to the new logical volume
      # ln -s /mnt/mysql/{dbName} {mysql-data-dir}/{dbName}/
      exec_link "#{mysql_data_dir}/#{$options[:database]}", mount_dir

      # # Change the permissions & ownership to MySQL 
      # chown -R mysql:mysql {mysql-data-dir}/{dbName}/
      # chown -R mysql:mysql /mnt/mysql/{dbName}/
      exec_chown "#{mysql_data_dir}/#{$options[:database]}"
      exec_chown mount_dir

      # Stop the MySQL Server
      $database.server_start

      on_rollback lambda {
        $database.server_stop
      }
    end

    def unmount
      volume_group_name = "#{$config['lvm']['volume_group']}"
      logical_volume_name = "#{$config['lvm']['prefix_database']}-#{$options[:database]}"
      mount_dir = get_mount_dir $options[:database]
      mysql_data_dir = $database.get_data_dir

      # Flush
      exec_flush

      # Stop the MySQL Server
      $database.server_stop

      on_rollback lambda {
        $database.server_start
      }

      # Unlink
      exec_unlink "#{mysql_data_dir}/#{$options[:database]}", mount_dir

      # Unmount
      exec_unmount "/dev/#{volume_group_name}/#{logical_volume_name}", mount_dir

      # Start the MySQL Server
      $database.server_start

      on_rollback lambda {
        $database.server_stop
      }
    end

    private
    def move_mysql_files from_dir, to_dir
      Dir.foreach(from_dir) do |filename|
        if !LOCKED_FILES.include?(filename) then
          run "Moving #{from_dir}/#{filename} to #{to_dir}",
            "mv #{from_dir}/#{filename} #{to_dir}"
        end
      end
    end

    private
    def get_mount_dir database
      "#{$config['filesystem']['mount']}/#{$config['lvm']['prefix_database']}-#{database}"
    end

    # Flush table
    private
    def exec_flush
      check "Flushing database to file system with read lock", lambda {
        $database.flush_lock
      }

      on_rollback lambda {
        check "Removing read lock", lambda { $database.unlock }
      }
    end

    # Mount the logical volume
    private
    def exec_mount device, directory
      # If it's already mounted, don't worry
      mount_status = Open4::popen4("mountpoint -q #{directory}") do |pid, stdin, stdout, stderr|
      end

      if mount_status == 0 then
        return
      end

      # Run command and set rollback
      run "Mounting logical volume", 
        "mount #{device} #{directory}"

      on_rollback lambda {
        run "Unmounting logical volume",
          "umount #{directory}"
      }
    end

    # Unmount
    private
    def exec_unmount device, directory
      # If it's not already mounted, don't worry
      mount_status = Open4::popen4("mountpoint -q #{directory}") do |pid, stdin, stdout, stderr|
      end

      if mount_status != 0 then
        return
      end

      # Run command and set rollback
      run "Unmounting logical volume",
        "umount #{directory}"

      on_rollback lambda {
        run "Mounting logical volume", 
          "mount #{device} #{directory}"
      }
    end

    # Symbolic-link
    private
    def exec_link entry, exit
      run "Linking symbolic directory",
        "ln -s #{exit} #{entry}"

      on_rollback lambda {
        run "Unlinking symbolic directory",
          "unlink #{entry}"
      }
    end

    # Remove symbolic link
    private
    def exec_unlink entry, exit
      run "Unlinking symbolic directory",
        "unlink #{entry}"

      on_rollback lambda {
        run "Linking symbolic directory",
          "ln -s #{exit} #{entry}"
      }
    end

    # Activate logical volume
    private 
    def exec_activate device
      run "Activating logical volume",
        "lvchange -ay #{device}"

      on_rollback lambda {
        run "Deactivate logical volume",
          "lvchange -an #{device}"
      }
    end

    # Activate logical volume
    private 
    def exec_deactivate device
      run "Deactivate logical volume",
        "lvchange -an #{device}"

      on_rollback lambda {
        run "Activating logical volume",
          "lvchange -ay #{device}"
      }
    end

    # Take ownership
    private
    def exec_chown directory
      run "Changing ownership",
        "chown -R mysql:mysql #{directory}"
    end
  end
end