require 'singleton'

module Snapback
  class Transaction
    include Singleton
    
    @@rollback_commands = []

    def add_rollback_method method
      @@rollback_commands.push method
    end

    def do_rollback
      while rollback_command = @@rollback_commands.pop do
        rollback_command.call
      end
    end
  end
end