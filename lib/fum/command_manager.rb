module Fum
  module CommandManager

    def self.included(includer)
      includer.instance_eval {
        @commands_map = Hash.new
        @command_path = "commands"

        def command(name, opts={})
          require ['fum', @command_path, name].join('/') #"fum/commands/#{name}"
          class_name = name.to_s.capitalize

          parent = @command_path.split('/').inject(Fum) { |mod, component|
            mod.const_get(component.capitalize)
          }

          @commands_map[name] = parent::const_get(class_name)


        end

        def command_path(path)
          @command_path = path
        end

        def create_commands(manager)
          map = {}
          @commands_map.each { |key, value|
            cmd = value.new
            cmd.command_manager = manager
            map[key] = cmd
          }
          map
        end

      }

    end

    def initialize
      @commands = self.class.create_commands(self)
    end

    def commands
      @commands
    end

    # Return an Array of command names as strings
    def command_names
      commands.keys.map { |c| c.to_s }
    end

    def parse_command_options(name)
      @commands[name.to_sym].parse_options
    end

    def run_command(name, options = {}, args=[])
      @commands[name.to_sym].execute(options, args)
    end

  end
end