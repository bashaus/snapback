require 'singleton'
require 'mysql'

# ## Database functions ##

module Snapback
  class Database
    include Singleton

    attr_accessor :hostname, :username, :password

    @connection = nil

    @hostname = ""
    @username = ""
    @password = ""

    def connect
      @connection = Mysql.new @hostname, @username, @password
    end

    def flush_lock
      begin
        @connection.query "FLUSH TABLES WITH READ LOCK"
      end

      true
    end

    def unlock
      begin
        @connection.query "UNLOCK TABLES"
      end

      true
    end

    def get_data_dir
      begin
        rs = @connection.query "SHOW VARIABLES LIKE 'datadir'"
        rs.each_hash do |row|
          return row['Value'].gsub(/\/$/, '')
        end
      end
    end

    def innodb_file_per_table
      begin
        rs = @connection.query "SHOW VARIABLES LIKE 'innodb_file_per_table'"
        rs.each_hash do |row|
          return row['Value'] == "ON"
        end
      rescue
        raise "MySQL Query failed"
      end
    end

    def set_innodb_file_per_table on
      begin
        rs = @connection.prepare "SET GLOBAL innodb_file_per_table = ?"
        rs.execute(on ? 'ON' : 'OFF')
        return true
      rescue
        raise "MySQL Query failed"
      end
    end

    def db_exists? database_name
      sql = @connection.list_dbs database_name
      sql.size == 1
    end

    def db_create database_name
      @connection.query "CREATE DATABASE `#{Mysql.escape_string database_name}`"
      true
    end

    def db_drop database_name
      @connection.query "DROP DATABASE `#{Mysql.escape_string database_name}`"
      true
    end

    def db_use database_name
      @connection.select_db database_name
      true
    end

    def server_stop
      run "Stop MySQL server",
        "service mysql stop"
      true
    end

    def server_start
      run "Start MySQL server and reconnect",
        "service mysql start"

      self.connect
      true
    end
  end
end