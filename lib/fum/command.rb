module Fum

  class Command

    attr_accessor :command_manager

=begin
    def initialize(manager)
      @command_manager = manager
    end
=end

    def command_name
      self.class.to_s.split("::").last.downcase
    end

    def parse_options
      options = {}
      option_parser(options).order!
      options
    end

    # Returns the help string for this command.
    def help
      option_parser.to_s
    end

    def add_options(opts, options)
      # Do nothing in base class.
    end

    def banner
      "usage: fum #{command_name} {options} "
    end

    # Checks first arg for a stage name.
    def stage_name_from_args(args)
      stage_name = args.shift
      die "No stage name specified." unless stage_name
      stage_name
    end

    def application_name
      @command_manager.definitions.nil? ? nil : @command_manager.definitions.name
    end

    def application_settings
      @command_manager.definitions.nil? ? nil : @command_manager.definitions.global_settings
    end

    # Return the stage declaration given app and name.
    def stage(name)
      die "No definition file loaded, please provide a stage definition file." if @command_manager.definitions.nil?
      @command_manager.definitions.stages[name.to_s] || die("Unknown stage '#{name}'")
    end

    private

    def die(msg)
      Fum::die(msg)
    end

    def option_parser(options = {})
      OptionParser.new do |opts|
        opts.banner = banner

        opts.on_tail("-h", "--help", "Display this help message.") do
          puts opts
          exit
        end

        add_options(opts, options)
      end
    end
  end

end