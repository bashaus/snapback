desc 'Take a database snapshot'
arg_name 'database [, ...]'
command :snapshot do |c|

  c.desc 'Disk size of changes expected'
  c.flag [:s, :size]

  c.action do |global_options,options,args|
    help_now!('parameter -s for size is required') if options[:s].nil?
    help_now!('database(s) required') if args.empty?

    # Load the configuration
    config = Snapback::ConfigurationLoader.factory global_options[:config]

    # Connect to MySQL
    mysql_client = config.mysql_client

    args.each do |database|

      # Start the transaction
      Snapback::Transaction.new do

        run_command "Selecting database: #{database}" do
          mysql_client.database_select(database)
        end

        vg_name = config.lvm_volume_group
        lv_name = "#{config.lvm_database_prefix}-#{database}"
        lv_path = "/dev/#{vg_name}/#{lv_name}"

        mount_database_directory  = config.filesystem_mount_directory(database)
        mysql_database_directory  = "#{mysql_client.get_data_directory}/#{database}"

        # Check

        lv_available = run_command "Checking logical volume name is available" do
          !File.exists?("/dev/#{vg_name}/#{config.lvm_snapshot_prefix}-#{database}")
        end

        if !lv_available then
          raise "Logical volume #{lv_path.colorize(:red)} already exist"
        end

        # Drop tablespaces
        tables = run_command "Getting list of tables in database" do
          mysql_client.database_tables
        end

        tables.each do |table|
          table = table.to_s
          run_command "Changing table engine to MyISAM: #{table}" do
            mysql_client.table_set_engine(table, "MyISAM")
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

        # Unlink
        run_command "Unlinking mysql data directory",
          "unlink #{mysql_database_directory}"

        revert do
          run_command "Linking mysql data directory",
            "ln -s #{mount_database_directory} #{mysql_database_directory}"
        end

        # Unmount
        run_command "Unmounting logical volume",
          "umount #{mount_database_directory}"

        revert do
          run_command "Mounting logical volume",
            "mount #{lv_path} #{mount_database_directory}"
        end

        # Deactivate
        run_command "De-activating logical volume",
          "lvchange -an #{lv_path}"

        revert do
          run_command "Re-activating logical volume",
            "lvchange -ay #{lv_path}"
        end
        
        # Branch the logical volume with a snapshot
        run_command "Snapshoting to #{config.lvm_snapshot_prefix}-#{database}",
          "lvcreate -L #{options[:s]} -s -n #{config.lvm_snapshot_prefix}-#{database} #{lv_path}"

        revert do
          run_command "Removing the snapshot",
            "lvremove -f /dev/#{vg_name}/#{config.lvm_snapshot_prefix}-#{database}"
        end

        # Active the master drive
        run_command "Activating logical volume",
          "lvchange -ay #{lv_path}"

        revert do
          run_command "Deactivating logical volume",
            "lvchange -an #{lv_path}"
        end

        # Mount the master drive
        run_command "Mounting logical volume",
          "mount #{lv_path} #{mount_database_directory}"

        revert do
          run_command "Unmounting logical volume",
            "umount #{mount_database_directory}"
        end

        # Symbolic-link the MySQL data directory to the new logical volume
        run_command "Linking mysql data directory",
          "ln -s #{mount_database_directory} #{mysql_database_directory}"

        revert do
          run_command "Unlinking mysql data directory",
            "unlink #{mysql_database_directory}"
        end

        # Change the permissions & ownership to MySQL
        run_command "Changing owner to mysql: #{mysql_database_directory}",
          "chown -R mysql:mysql #{mysql_database_directory}"

        run_command "Changing owner to mysql: #{mount_database_directory}",
          "chown -R mysql:mysql #{mount_database_directory}"

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