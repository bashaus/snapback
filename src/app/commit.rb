require "singleton"

module Blanketdb
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