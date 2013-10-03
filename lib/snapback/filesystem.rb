module Snapback
  class Filesystem

    LOCKED_FILES = ['.', '..', 'lost+found']

    def self.mount(device, directory)
      # If it's already mounted, don't worry
      mount_status = Open4::popen4("mountpoint -q #{directory}") do |pid, stdin, stdout, stderr|
      end

      if mount_status == 0 then
        return true
      end

      `mount #{device} #{directory}`
    end

    def self.unmount(directory)
      # If it's already unmounted, don't worry
      mount_status = Open4::popen4("mountpoint -q #{directory}") do |pid, stdin, stdout, stderr|
      end

      if mount_status != 0 then
        return true
      end

      `umount #{directory}`
    end

    def self.move_mysql_files(from_directory, to_directory)
      Dir.foreach(from_directory) do |filename|
        if !LOCKED_FILES.include?(filename) then
          run_command "Moving #{from_directory}/#{filename} to #{to_directory}",
            "mv #{from_directory}/#{filename} #{to_directory}"
        end
      end
    end
  end
end