require "colorize"
require "open4"

LOCKED_FILES = ['.', '..', 'lost+found']

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


# Move MySQL Files
def move_mysql_files from_dir, to_dir
  Dir.foreach(from_dir) do |filename|
    if !LOCKED_FILES.include?(filename) then
      run "Moving #{from_dir}/#{filename} to #{to_dir}",
        "mv #{from_dir}/#{filename} #{to_dir}"
    end
  end
end

def get_mount_dir database
  "#{$config['filesystem']['mount']}/#{$config['lvm']['prefix_database']}-#{database}"
end

# Flush table
def exec_flush
  check "Flushing database to file system with read lock", lambda {
    $database.flush_lock
  }

  on_rollback lambda {
    check "Removing read lock", lambda { $database.unlock }
  }
end

# Mount the logical volume
def exec_mount device, directory
  # If it's already mounted, don't worry
  mount_status = Open4::popen4("mountpoint -q #{directory}") do |pid, stdin, stdout, stderr|
  end

  if mount_status == 0 then
    return
  end

  # Run command and set rollback
  run "Mounting logical volume", 
    "mount #{device} #{directory}"

  on_rollback lambda {
    run "Unmounting logical volume",
      "umount #{directory}"
  }
end

# Unmount
def exec_unmount device, directory
  # If it's not already mounted, don't worry
  mount_status = Open4::popen4("mountpoint -q #{directory}") do |pid, stdin, stdout, stderr|
  end

  if mount_status != 0 then
    return
  end

  # Run command and set rollback
  run "Unmounting logical volume",
    "umount #{directory}"

  on_rollback lambda {
    run "Mounting logical volume", 
      "mount #{device} #{directory}"
  }
end

# Symbolic-link
def exec_link entry, exit
  run "Linking symbolic directory",
    "ln -s #{exit} #{entry}"

  on_rollback lambda {
    run "Unlinking symbolic directory",
      "unlink #{entry}"
  }
end

# Remove symbolic link
def exec_unlink entry, exit
  run "Unlinking symbolic directory",
    "unlink #{entry}"

  on_rollback lambda {
    run "Linking symbolic directory",
      "ln -s #{exit} #{entry}"
  }
end

# Activate logical volume
def exec_activate device
  run "Activating logical volume",
    "lvchange -ay #{device}"

  on_rollback lambda {
    run "Deactivate logical volume",
      "lvchange -an #{device}"
  }
end

# Activate logical volume
def exec_deactivate device
  run "Deactivate logical volume",
    "lvchange -an #{device}"

  on_rollback lambda {
    run "Activating logical volume",
      "lvchange -ay #{device}"
  }
end

# Take ownership
def exec_chown directory
  run "Changing ownership",
    "chown -R mysql:mysql #{directory}"
end