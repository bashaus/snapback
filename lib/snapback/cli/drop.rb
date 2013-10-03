desc 'Drop an existing database'
arg_name 'database [, ...]'
command :drop do |c|
  c.action do |global_options,options,args|
    help_now!('database(s) required') if args.empty?

    # Load the configuration
    config = Snapback::ConfigurationLoader.factory global_options[:config]

    # Connect to MySQL
    mysql_client = config.mysql_client

    args.each do |database|

      # Start the transaction
      Snapback::Transaction.new do
        run_command "Selecting database: #{database}" do
          mysql_client.db_use(database)
        end

        vg_name = config.lvm_volume_group
        lv_name = "#{config.lvm_database_prefix}-#{database}"
        lv_path = "/dev/#{vg_name}/#{lv_name}"

        mount_database_directory  = config.filesystem_mount_directory(database)
        mysql_database_directory  = "#{mysql_client.get_data_directory}/#{database}"

        # # Remove the backup
        # Snapback::App::Commit.instance.go

        # Drop tablespaces
        tables = run_command "Getting list of tables in database" do
          mysql_client.db_tables
        end

        tables.each do |table|
          table = table.to_s
          run_command "Dropping table: #{table}" do
            mysql_client.discard_and_drop_table(table)
          end
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

        run_command "Unlinking mysql data directory",
          "unlink #{mysql_database_directory}"

        revert do
          run_command "Linking mysql data directory",
            "ln -s #{mount_database_directory} #{mysql_database_directory}"
        end

        # Mount the new logical volume
        run_command "Unmounting logical volume",
          "umount #{mount_database_directory}"

        revert do
          run_command "Mounting logical volume",
            "mount #{lv_path} #{mount_database_directory}"
        end

        # Remove logical volume
        run_command "Remove logical volume", 
          "lvremove -f #{lv_path}"

        # Start MySQL
        run_command "Starting MySQL server" do
          Snapback::MySQL::ServiceControl.start
        end

        revert do
          run_command "Stopping MySQL server" do
            Snapback::MySQL::ServiceControl.stop
          end
        end
      end
    end
  end
end