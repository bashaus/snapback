require "singleton"

module Snapback
  module App
    class Snapshot
      include Singleton

      def go
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
    end
  end
end