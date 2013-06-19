require "singleton"

module Snapback
  module App
	  class Commit
	    include Singleton

	    def go
	      # Remove the backup
	      # lvremove /dev/DEFAULT/backup-{dbName}
	    end
	  end
	end
end