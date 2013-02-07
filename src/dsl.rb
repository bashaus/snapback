require "colorize"

# DSL: on_rollback
# Add a callback if a method (somewhere) fails
def on_rollback method
  Blanketdb::Transaction.instance.add_rollback_method method
end

def run description, command
  puts "#{command}".yellow if $options[:verbose]
  debug "#{description}".ljust(72)

  begin
    err = ""
    status = Open4::popen4(command) do |pid, stdin, stdout, stderr|
      err = stderr.read
    end

    if status != 0 then
      raise err
    end
  rescue
    show_failed
    raise $!
  end

  show_ok
end

def check description, command
  print description.ljust(72)
  result = command.call
  if result == true then
    show_ok
  else
    show_no
  end

  result
end

def debug *args
  print "#{args}"
end

def show_ok
  puts "[#{"  OK  ".green}]"
end

def show_no
  puts "[#{"  NO  ".red}]"
end

def show_failed
  puts "[#{"FAILED".red}]"
end

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