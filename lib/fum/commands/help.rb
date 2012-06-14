module Fum
  module Commands
    class Help < Fum::Command

      def banner
        super << "<command>"
      end

      def add_options(opts, options)
        opts.separator ""
        opts.separator "Available commands are:"
        @command_manager.command_names.each { |name|
          opts.separator "  #{name}"
        }
        opts.separator ""
        opts.separator "Options are:"
      end


      def execute(options, args)
        command = args.shift

        Fum::die help if command.nil?

        # No help for the helpless.
        Fum::die "How much help do you need?" if command == "help"

        puts "No such command ''#{command}'.'" if !@command_manager.command_names.include?(command)

        puts @command_manager.commands[command.to_sym].help
      end

    end


  end
end