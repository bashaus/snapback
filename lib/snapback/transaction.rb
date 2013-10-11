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
      if Snapback.verbose?
        puts ""
        puts "An error occurred ... rolling back"
        puts ""
      end

      while revert = @reverts.pop
        revert.call
      end
      
      
      puts "" if Snapback.verbose?
    end
  end
end