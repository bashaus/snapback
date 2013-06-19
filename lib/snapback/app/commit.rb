require "singleton"

module Snapback
  module App
	  class Commit
	    include Singleton

	    def go
        volume_group_name = "#{$config['lvm']['volume_group']}"
        logical_volume_name = "#{$config['lvm']['prefix_backup']}-#{$options[:database]}"

        # Flush
        exec_flush

        # Stop the MySQL Server
        $database.server_stop

        on_rollback lambda {
          $database.server_start
        }

        # Remove logical volume
        run "Committing logical volume", 
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