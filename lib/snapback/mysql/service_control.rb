module Snapback
  module MySQL
    class ServiceControl

      def self.start
        `service mysql start`
      end

      def self.stop
        `service mysql stop`
      end
    end
  end
end