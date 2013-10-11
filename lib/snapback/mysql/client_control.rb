require 'singleton'
require 'mysql'

module Snapback
  module MySQL
    class ClientControl
      include Singleton

      attr_accessor :hostname, :username, :password

      # Connection

      @connection = nil

      @hostname = ""
      @username = ""
      @password = ""

      def connect
        @connection = Mysql.new @hostname, @username, @password
      end

      # Maintenance

      def flush_tables
        @connection.query "FLUSH TABLES WITH READ LOCK"
        true
      end

      def unlock_tables
        @connection.query "UNLOCK TABLES"
        true
      end

      # Configuration

      def get_data_directory
        rs = @connection.query "SHOW VARIABLES LIKE 'datadir'"
        rs.each_hash do |row|
          return row['Value'].gsub(/\/$/, '')
        end
      end

      def has_innodb_file_per_table?
        rs = @connection.query "SHOW VARIABLES LIKE 'innodb_file_per_table'"
        rs.each_hash do |row|
          return row['Value'] == "ON"
        end
      end

      def set_innodb_file_per_table(on)
        rs = @connection.prepare "SET GLOBAL innodb_file_per_table = ?"
        rs.execute(on ? 'ON' : 'OFF')
      end

      # Database

      def database_exists?(database)
        @connection.list_dbs(database).size == 1
      end

      def database_create(database)
        begin
          @connection.query "CREATE DATABASE `#{Mysql.escape_string database}`"
          true
        rescue
          false
        end
      end

      def database_select(database)
        @connection.select_db(database)
      end

      def database_tables
        @connection.query "SHOW TABLES"
      end

      # Tables

      def table_drop(table)
        begin
          @connection.query "DROP TABLE `#{Mysql.escape_string table}`"
          true
        rescue
          false
        end
      end

      def table_optimize(table)
        begin
          @connection.query "ALTER TABLE `#{Mysql.escape_string table}` IMPORT TABLESPACE"
        rescue
          # If this fails, it's usually just because the table is not InnoDB, so ignore errors
        end

        begin
          @connection.query "OPTIMIZE TABLE `#{Mysql.escape_string table}`"
          true
        rescue
          false
        end
      end

      def table_set_engine(table, engine)
        begin
          @connection.query "ALTER TABLE `#{Mysql.escape_string table}` ENGINE = #{Mysql.escape_string engine};"
          true
        rescue
          false
        end
      end

      # Tablespace
      def tablespace_discard(table)
        begin
          @connection.query "ALTER TABLE `#{Mysql.escape_string table}` DISCARD TABLESPACE"
          true
        rescue
          false
        end
      end
    end
  end
end