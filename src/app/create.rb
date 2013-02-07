require "singleton"

module Blanketdb
  module App
    class Create
      include Singleton

      def go
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
    end
  end
end