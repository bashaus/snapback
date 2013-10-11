require 'colorize'
require 'open4'

require 'snapback/transaction'
require 'snapback/filesystem'

# Command

module Snapback
  @@verbose = false

  def self.set_quiet
    @@verbose = true
  end

  def self.set_verbose
    @@verbose = false
  end

  def self.quiet?
    @@verbose == true
  end

  def self.verbose?
    @@verbose == false
  end
end

def run_command description, command = "", &block
  if Snapback.verbose?
    print "#{description}".to_s.ljust(72)
    STDOUT.flush
  end

  begin
    if block_given? then
      result = block.call

      if result then
        return_ok
      else
        return_no
      end
    else
      err = ""
      status = Open4::popen4(command) do |pid, stdin, stdout, stderr|
        err = stderr.read
      end

      if status != 0 then
        raise err
      end

      return_ok
    end
  rescue Exception => e 
    return_failed
    raise $! # rethrow
  end

  return result
end

# Output status

def return_ok
  return nil if Snapback.quiet?
  puts "[#{"  OK  ".colorize(:green)}]"
end

def return_no
  return nil if Snapback.quiet?
  puts "[#{"  NO  ".colorize(:red)}]"
end

def return_failed
  return nil if Snapback.quiet?
  puts "[#{"FAILED".colorize(:red)}]"
end

# Ask

def ask_int question, max
  number = nil

  while true
    print "#{question}: "

    number = $stdin.gets.chomp

    if !Integer(number) then
      puts "The value you entered is not a number."
      puts ""
      next
    end

    number = number.to_i

    if number < 1 || number > max then
      puts "Please enter a number between 1 and #{max}."
      puts ""
      next
    end

    break
  end

  number
end

def ask_string question
  print "#{question}: "
  $stdin.gets.chomp
end

def ask_confirm question
  while true
    print "#{question} [Y/N]: "

    confirmed = $stdin.gets.chomp.upcase

    if confirmed.eql? 'Y' then
      return true
    elsif confirmed.eql? 'N' then
      return false
    else
      puts "Please enter either Y or N."
    end
  end
end