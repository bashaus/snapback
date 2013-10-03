require 'snapback/configuration/configuration_0_0_2'

module Snapback
  class ConfigurationLoader
    def initialize(options={}) #:nodoc:
    end

    def self.factory filename
      begin
        # Read confirmation options
        configuration = YAML.load_file filename
      rescue
        raise "Could not load configuration file: #{filename}"
      end

      case configuration['version']
      when "0.0.2"
        ::Snapback::Configuration::Configuration_0_0_2.new configuration
      else
        raise "Unknown configuration version: #{configuration['version']}"
      end
    end
  end
end
