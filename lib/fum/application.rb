
require 'rubygems'
require 'fum/lang/fum_file'

require 'optparse'

module Fum

  def die(msg)
    puts msg
    exit 1
  end

  class Application
    include CommandManager

    attr_accessor :definitions

    attr_accessor :command_name, :command_options, :command_args
    attr_accessor :fum_file

    command :events
    command :help
    command :launch
    command :list
    command :repair
    command :status
    command :tail
    command :template
    command :terminate

    DEFAULT_CONFIG = File.expand_path('~/.fum')

    def start

      begin
        handle_options
        load_definitions
        run
      rescue FatalError => ex
        puts ex
        exit(false)
      end

    end

    def run
      run_command(command_name, command_options, command_args)
    end

    def handle_options
      # Parse and load default options from config
      parsed_options = parse_options
      options = load_config.merge(parsed_options)

      # Process options
      Fum.verbose = options[:verbose]
      Fum.noop = options[:noop]

      options[:aws_region] ||= 'us-east-1'

      if options[:aws_access_key] && options[:aws_secret_key]

        Fog.credentials = {
            :aws_access_key_id => options[:aws_access_key],
            :aws_secret_access_key => options[:aws_secret_key],
            :region => options[:aws_region]
        }
      else
        Fum::die "Must provide AWS access and secret keys on command line or via a config file."
      end
    end

    def parse_options
      # If first arg is not an option or command, assume it is the fum file to load.
      if ARGV.length > 0 && !ARGV[0].start_with?("-") && !command_names.include?(ARGV[0])
        @fum_file = ARGV.shift
      end

      # Set defaults
      options = {
          :verbose => false,
          :noop => false
      }
      @config_file = ENV['FUM_CONFIG']

      globals = OptionParser.new do |opts|
        opts.banner = "fum [fum_file] {options} {command} {command-options}"
        opts.separator ""
        opts.separator "Available commands..."
        command_names.each { |cmd|
          opts.separator("  #{cmd}")
        }
        opts.separator ""
        opts.separator "Global options are..."


        opts.on_tail("-h", "--help", "Display this help message.") do
          puts opts
          exit
        end

        opts.on_tail("-v", "--version", "Show version") do
          puts "fum version #{Fum::VERSION}"
          exit
        end

        opts.on('--config CONFIG', '-c CONFIG',
                "Load configuration options from CONFIG instead of ~/.fum") { |value| @config_file = value }

        opts.on('--file FILE', '-f FILE',
                "Load fum definitions from FILE (if not specified as first argument).") { |value| @fum_file = value}

        opts.on('--aws-access-key ACCESS_KEY', '-k ACCESS_KEY',
                'AWS access key id') { |value| options[:aws_access_key] = value }

        opts.on('--aws-secret-key ACCESS_KEY', '-s SECRET_KEY',
                'AWS secret key id') { |value| options[:aws_secret_key] = value }

        opts.on('--aws-region REGION', '-r REGION',
                'AWS Region id') { |value| options[:aws_region] = value }

        opts.on('--noop', '-n', "Do nothing, print steps to be executed.") { |value| options[:noop] = true }
        opts.on('--[no-]verbose', 'Enables verbose output.') { |value| options[:verbose] = value }

        opts.environment('FUM_OPT')
      end

      begin
        # Parse global options
        globals.order!

        # Exit if no command
        if ARGV.empty?
          puts globals.help
          exit(false)
        end

        @command_name = ARGV.shift
        if command_names.include?(@command_name)
          @command_options = parse_command_options(@command_name.to_sym)
          @command_args = ARGV
        else
          puts "'#{@command_name}' is not a fum command. See 'fum --help'."
          exit(false)
        end
      rescue OptionParser::InvalidOption => ex
        puts ex.message
        exit(false)
      end

      options
    end

    def load_config
      require 'yaml'
      if @config_file && File.readable?(@config_file)
        YAML.load(File.read(@config_file))
      elsif File.readable?(DEFAULT_CONFIG)
        YAML.load(File.read(DEFAULT_CONFIG))
      else
        Hash.new
      end

    end

    def load_definitions
      if @fum_file
        @definitions = Fum::Lang::FumFile.load(@fum_file)
      end
    end

  end

end

