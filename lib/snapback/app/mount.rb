require "singleton"

module Snapback
  module App
    class Mount
      include Singleton

      def go
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
    end
  end
end