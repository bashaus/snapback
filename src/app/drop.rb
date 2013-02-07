require "singleton"
require "src/app/commit"

module Blanketdb
  module App
    class Drop
      include Singleton

      def go
        volume_group_name = "#{$config['lvm']['volume_group']}"
        logical_volume_name = "#{$config['lvm']['prefix_database']}-#{$options[:database]}"
        mount_dir = get_mount_dir $options[:database]
        mysql_data_dir = $database.get_data_dir

        # Remove the backup
        Blanketdb::App::Commit.instance.go

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
    end
  end
end