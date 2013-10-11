require 'snapback/configuration_loader'
require 'snapback/mysql/service_control'

desc 'Commit the working copy of the database'
arg_name 'database [, ...]'
command :commit do |c|
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
          mysql_client.database_select(database)
        end

        vg_name = config.lvm_volume_group
        lv_name = "#{config.lvm_database_prefix}-#{database}"
        lv_path = "/dev/#{vg_name}/#{lv_name}"

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

        # Commit LVM
        run_command "Commit logical volume" do
          exec "lvremove -f #{lv_path}"
        end

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