require 'lvm'
require 'snapback/configuration_loader'

desc 'Ensure the environment is setup'
command :install do |c|
  c.action do |global_options,options,args|
    help_now!('found arguments, none expected') if !args.empty?

    Snapback::Transaction.new do

      puts ""
      puts "Hi!"
      puts ""
      puts "I'm going to guide you through setting up #{"snapback".colorize(:green)}. "
      puts "This script will check to see if your environment can run "
      puts "Snapback and will setup configuration files for you."
      puts ""

      run_command "Checking LVM is installed",
        "lvm version"

      lvm = nil
      volume_groups = nil

      # Get information from LVM
      run_command "Retrieving volume group information" do
        lvm = LVM::LVM.new({:command => "sudo lvm", :version => "2.02.30"})
        volume_groups = lvm.volume_groups.to_a

        if volume_groups.size == 0 then
          raise "LVM is not setup: you do not have any volume groups"
        end

        true
      end

      puts ""

      selected_volume_group = nil

      # Decide which volume group to use
      if volume_groups.size == 1 then
        selected_volume_group = volume_groups[0];
        puts "There is one volume group available"
      else
        puts "There are multiple volume groups available:"

        volume_groups.each_with_index.map { |volume_group, index|
          puts "  #{index + 1}.\t#{volume_group.name.colorize(:yellow)}"
        }

        puts ""

        volume_group_number = ask_int "Which volume group would you like Snapback use", volume_groups.size
        selected_volume_group = volume_groups[volume_group_number - 1];
      end

      puts "Snapback will use the volume group #{selected_volume_group.name.colorize(:green)}"
      puts ""

      # Check for mount directory
      mysql_mount_directory = ask_string "Where do you want to mount your logical volumes [/mnt/mysql]"
      mysql_mount_directory = "/mnt/mysql" if mysql_mount_directory.empty?

      run_command "Changing owner to mysql: #{mysql_mount_directory}",
        "chown -R mysql:mysql #{mysql_mount_directory}"

      has_mysql_mount_directory = run_command "Checking for directory #{mysql_mount_directory}" do
          File.directory? mysql_mount_directory
      end

      if !has_mysql_mount_directory then
        run_command "Creating directory #{mysql_mount_directory}",
          "mkdir -p #{mysql_mount_directory}"

        revert do
          run_command "Removing directory #{mysql_mount_directory}",
            "rm -rf #{mysql_mount_directory}"
        end
      end

      # MySQL connection
      mysql_client = Snapback::MySQL::ClientControl.instance

      while true
        puts ""
        puts "Enter the credentials to connect to MySQL on localhost"

        mysql_client.hostname = "localhost"
        
        # Ask for username
        mysql_client.username = ask_string "MySQL username [root]"
        mysql_client.username = "root" if mysql_client.username.empty?

        # Ask for password
        mysql_client.password = ask_string "MySQL password"

        connected = run_command "Connecting to MySQL database" do
          begin
            mysql_client.connect
            true
          rescue
            false
          end
        end

        if connected then
          break
        else
          next
        end
      end

      # MySQL properties

      has_innodb_file_per_table = run_command "Checking innodb_file_per_table is activated" do
        mysql_client.has_innodb_file_per_table?
      end

      if !has_innodb_file_per_table then
        run_command "Setting innodb_file_per_table to ON" do
          mysql_client.set_innodb_file_per_table true
        end

        revert do
          run_command "Setting innodb_file_per_table to OFF" do
            mysql_client.set_innodb_file_per_table false
          end
        end
      end

      run_command "Writing configuration to file" do
        config = {
          'version' => Snapback::VERSION,
          'lvm' => {
            'volume_group'    => "#{selected_volume_group.name}",
            'database_prefix' => "snapback-database",
            'snapshot_prefix' => "snapback-snapshot"
          },

          'mysql' => {
            'hostname'        => mysql_client.hostname,
            'username'        => mysql_client.username,
            'password'        => mysql_client.password
          },

          'filesystem' => {
            'mount'           => mysql_mount_directory
          }
        }

        File.open(global_options[:config], 'w+') { |f| f.write(config.to_yaml) }
      end

      revert do
        run_command "Removing configuration file" do
          File.unlink global_options[:config]
        end
      end

      puts ""
      puts "Snapback has now been configured."
      puts "To start using Snapback, run the following command: "
      puts ""
      puts "sudo snapback help".colorize(:yellow)
      puts ""
      puts "If your operating system uses AppArmor (e.g.: Ubuntu) you will need to "
      puts "manually update your #{"/etc/apparmor.d/usr/sbin/mysqld".colorize(:green)} file "
      puts "to include the following lines:"
      puts "\t#{"/mnt/mysql/ rwk,".colorize(:green)}"
      puts "\t#{"/mnt/mysql/** rwk,".colorize(:green)}"
      puts ""
      puts "Then manually restart AppArmor and MySQL using: "
      puts "\t#{"service apparmor restart".colorize(:green)}"
      puts "\t#{"service mysql restart".colorize(:green)}"
      puts ""
    end
  end
end