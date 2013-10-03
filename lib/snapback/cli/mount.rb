desc 'Mount an existing database'
arg_name 'database [, ...]'
command :mount do |c|
  c.action do |global_options,options,args|
    # Ensure all flags and switches are present
    help_now!('database(s) required') if args.empty?

    # Load the configuration
    config = Snapback::ConfigurationLoader.factory global_options[:config]

    # Connect to MySQL
    mysql_client = config.mysql_client

    # For each database
    args.each do |database|

      # Start the transaction
      Snapback::Transaction.new do
        run_command "Selecting database: #{database}" do
          mysql_client.db_use(database)
        end

        vg_name = config.lvm_volume_group
        lv_name = config.lvm_logical_database database
        lv_path = "/dev/#{vg_name}/#{lv_name}"

        mount_database_directory  = config.filesystem_mount_directory(database)
        mysql_database_directory  = "#{mysql_client.get_data_directory}/#{database}"

        lv_exists = run_command "Checking logical volume exists" do
          File.exists?(lv_path)
        end

        if !lv_exists then
          raise "Logical volume #{lv_path.colorize(:red)} does not exist"
        end

        # Flush
        run_command "Flush tables with read lock" do
          mysql_client.flush_tables
        end

        # Stop MySQL
        run_command "Stop MySQL server" do
          Snapback::MySQL::ServiceControl.stop
        end

        revert do
          run_command "Start MySQL server" do
            Snapback::MySQL::ServiceControl.start
          end
        end

        directory_exists = run_command "Checking if mount directory exists" do
          File.directory? mount_database_directory
        end

        # Check mount directory exists
        if !directory_exists then
          run_command "Creating mount directory",
            "mkdir #{mount_database_directory}"

          revert do
            run_command "Removing mount directory",
              "rmdir #{$mount_database_directory}"
          end

          run_command "Changing permissions of mount directory",
            "chmod 0777 #{mount_database_directory}"
        end

        run_command "Mounting directory",
          "mount #{lv_path} #{mount_database_directory}"

        run_command "Linking mount directory",
          "ln -s #{mount_database_directory} #{mysql_database_directory}"

        run_command "Changing ownership of: #{mount_database_directory}",
          "chown -R mysql:mysql #{mount_database_directory}"

        run_command "Changing ownership of: #{mysql_database_directory}",
          "chown -R mysql:mysql #{mysql_database_directory}"

        # Start MySQL
        run_command "Start MySQL server" do
          Snapback::MySQL::ServiceControl.start
        end

        revert do
          run_command "Stop MySQL server" do
            Snapback::MySQL::ServiceControl.stop
          end
        end
      end
    end
  end
end