require "singleton"

module Blanketdb
  module App
    class Rollback
      include Singleton

      def go
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
    end
  end
end