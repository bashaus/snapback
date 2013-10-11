desc 'Create a new snapback compliant database'
arg_name 'database [, ...]'
command :create do |c|

  c.desc 'Disk size of database to create'
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

        vg_name = config.lvm_volume_group
        lv_name = "#{config.lvm_database_prefix}-#{database}"
        lv_path = "/dev/#{vg_name}/#{lv_name}"

        mount_database_directory  = config.filesystem_mount_directory(database)
        mysql_database_directory  = "#{mysql_client.get_data_directory}/#{database}"

        database_exists = run_command "Checking database exists: #{database}" do
          mysql_client.database_exists?(database)
        end

        if !database_exists then
          run_command "Creating database: #{database}" do
            mysql_client.database_create(database)
          end

          revert do
            run_command "Dropping database: #{database}" do
              mysql_client.db_drop(database)
            end
          end
        end

        lv_available = run_command "Checking logical volume name is available" do
          !File.exists?(lv_path)
        end

        if !lv_available then
          raise "Logical volume #{lv_path.colorize(:red)} already exist"
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

        # Logical volume management
        run_command "Create logical volume",
          "lvcreate -L #{options[:s]} -n #{lv_name} #{vg_name}"

        revert do
          run_command "Removing logical volume",
            "lvremove -f #{vg_name}/#{lv_name}"
        end

        run_command "Format logical volume filesystem",
          "mkfs.ext4 #{lv_path}"

        # Create a new directory for where the MySQL database can be mounted
        # mkdir /mnt/mysql/{dbName};

        mount_diectory_exists = run_command "Checking mount directory: #{mount_database_directory}" do
          File.directory? mount_database_directory
        end

        if !mount_diectory_exists then
          run_command "Make mount directory",
            "mkdir #{mount_database_directory}"

          revert do
            run_command "Removing mount directory",
              "rm -rf #{$mount_database_directory}"
          end
        end

        run_command "Changing permissions of mount directory",
          "chmod 0777 #{mount_database_directory}"

        # Mount the new logical volume
        run_command "Mounting logical volume",
          "mount #{lv_path} #{mount_database_directory}"

        revert do
          run_command "Unmounting logical volume",
            "umount #{mount_database_directory}"
        end

        # Move the contents of the database to the new logical volume
        Snapback::Filesystem.move_mysql_files(mysql_database_directory, mount_database_directory)

        revert do
          Snapback::Filesystem.move_mysql_files(mount_database_directory, mysql_database_directory)
        end

        # Remove the folder in the MySQL data directory
        
        run_command "Remove mysql database directory",
          "rm -rf #{mysql_database_directory}"

        revert do
          run_command "Re-creating MySQL database directory",
            "mkdir #{mysql_database_directory}"
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