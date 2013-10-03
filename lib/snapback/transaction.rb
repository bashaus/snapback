module Snapback
  class Transaction

    def initialize(&block)
      @reverts = []

      begin
        instance_eval &block
      rescue Exception => msg  
        rollback
        raise msg # re-throw
      end
    end

    def revert(&block)
      @reverts.push block
    end

    def rollback
      puts ""
      puts "An error occurred ... rolling back"
      puts ""

      while revert = @reverts.pop
        revert.call
      end
      
      puts ""
    end
  end
end