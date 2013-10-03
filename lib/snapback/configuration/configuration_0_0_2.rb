require 'snapback/mysql/client_control'

module Snapback
  module Configuration
    class Configuration_0_0_2

      def initialize(yaml)
        @@yaml = yaml
      end

      def version
        @@yaml['version']
      end

      def lvm_volume_group
        begin
          @@yaml['lvm']['volume_group']
        rescue
          nil
        end
      end

      def lvm_logical_database(database)
        begin
          "#{@@yaml['lvm']['database_prefix']}-#{database}"
        rescue
          "snapback-database-#{database}"
        end
      end

      def lvm_logical_snapshot(database)
        begin
          "#{@@yaml['lvm']['snapshot_prefix']}-#{database}"
        rescue
          "snapback-snapshot-#{database}"
        end
      end
      
      def lvm_database_prefix
        begin
          @@yaml['lvm']['database_prefix']
        rescue
          nil
        end
      end

      def lvm_snapshot_prefix
        begin
          @@yaml['lvm']['snapshot_prefix']
        rescue
          nil
        end
      end

      def mysql_client
        client = Snapback::MySQL::ClientControl.instance

        client.hostname = mysql_hostname
        client.username = mysql_username
        client.password = mysql_password
        client.connect

        client
      end

      def mysql_hostname
        begin
          @@yaml['mysql']['hostname']
        rescue
          nil
        end
      end
      
      def mysql_username
        begin
          @@yaml['mysql']['username']
        rescue
          nil
        end
      end

      def mysql_password
        begin
          @@yaml['mysql']['password']
        rescue
          nil
        end
      end

      def filesystem_mount_directory(database)
        begin
          "#{@@yaml['filesystem']['mount']}/#{database}"
        rescue
          "/mnt/snapback-#{database}"
        end
      end
    end
  end
end