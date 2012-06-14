require 'formatador'
require 'formatador/table'
require 'json'

module Fum
  module Commands
    class Template < Fum::Command
      include Fum::CommandManager

      # Helper class for template commands
      class Command < Fum::Command

        def application_name
          @command_manager.application_name
        end

        def template(name, app_name = application_name)
          die "No template specified." if name.nil?
          template = Fog::AWS[:beanstalk].templates.get(app_name, name)
          die "No configuration template named #{name} for application #{app_name}." if template.nil?
          template
        end

      end

      command_path 'commands/template'

      command :compare
      command :create
      command :delete
      command :list
      command :options
      command :settings
      command :update

=begin
      def tparse_options
        options = Trollop::options do
          banner "usage: template [options] <environment-id>, where options are:"

          opt :json, "Output in JSON format"
          opt :application, "Application name (for creating templates only)", :type => :string
          opt :description, "Description (update/create only)", :type => :string
          #opt :prompt, "Prompt for options when updating or creating"
          opt :stack, "Use the specified solution stack.", :type => :string

          opt :from_template, "Base template to use when creating a new template", :type => :string
          opt :from_json, "JSON File to use for create or update", :type => :string
          opt :from_application, "Application to use for source template", :type => :string
        end
        if options[:options] || options[:settings] || options[:create] || options[:update] || options[:delete]
          if ARGV.empty?
            die "Please specify a template name for this operation"
          else
            options[:template_name] = ARGV.shift
          end
        elsif options[:compare]
          die "Please specify two templates to compare" unless ARGV.length >= 2
          options[:template_names] = ARGV.dup
        end


        options
      end
=end

      def application_name
        @command_manager.definitions.nil? ? @application_name : @command_manager.definitions.name
      end


      def parse_options
        options = {}

        globals = OptionParser.new do |opts|
          opts.banner = "#{$0} [fum_file] {global-options} template {command} {command-options}"
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


          opts.on('--application APPNAME', '-a APPNAME',
                  "Application name of templates if no fum file specified.") { |value| @application_name = value }

        end


        begin
          # Parse global options
          globals.order!

          # Exit if no command
          if ARGV.empty?
            puts globals.help
            exit(false)
          end

          options[:command_name] = ARGV.shift
          if command_names.include?(options[:command_name])
            options.merge!(parse_command_options(options[:command_name].to_sym))
          else
            puts "Unknown template command '#{options[:command_name]}'. See '#{$0} template --help'."
            exit(false)
          end
        rescue OptionParser::InvalidOption => ex
          puts ex.message
          exit(false)
        end

        options
      end

      #
      #
      # * :type
      def execute(options, args)
        run_command(options[:command_name], options, args)
      end


      def old
        app = @command_manager.definitions

        # TODO make sure only one of these is is set, for now do least destructive order.
        if options[:settings] || options[:update] || options[:options] || options[:delete]

          template = Fog::AWS[:beanstalk].templates.get(app.name, options[:template_name])
          die "No configuration template named #{options[:template_name]}" if template.nil?

          if options[:settings]
            display_settings(template.option_settings, options)
          elsif options[:options]
            display_options(template.options, options)
          elsif options[:update]
            update_template(template, options)
          elsif options[:delete]
            template.destroy
            puts "Deleted template #{template.name}."
          end
        elsif options[:create]
          create_template(options)
        elsif options[:compare]
          compare_settings(options)
        elsif options[:stack]
          begin
            config_opts = Fog::AWS[:beanstalk].describe_configuration_options('SolutionStackName' => options[:stack])
            config_opts = config_opts.body['DescribeConfigurationOptionsResult']['Options']
            display_options(config_opts, options)
          rescue Fog::AWS::ElasticBeanstalk::InvalidParameterError => ex
            die ex.message
          end
        end

      end


=begin

      # Work in progress on prompting for options - move to branch
      def prompt_options(template, options)
        require 'highline/import'
        opts = template.options.sort_by { |a| [ a["Namespace"], a["Name"]]}
        option_settings = template.option_settings

        opts.each { |option|

          answer_type = nil
          if option['MinValue'] && option['MaxValue']
            answer_type = Integer
          elsif option['ValueOptions']
            #type = value['ValueType'] == 'List' ? 'List' : 'Scalar'
            answer_type = option['ValueOptions']
            answer_type << ""
          elsif option['Regex']
            #answer_type = "Regex(#{value['Regex']['Label']} = #{value['Regex']['Pattern']})"
          elsif option['ValueType'] == 'Boolean'
            answer_type = %w(true false)
          end

          value = ask("#{option['Namespace']}:#{option['Name']} ? ", answer_type) { |q|
            setting = option_settings.select { |a| a['OptionName'] == option['Name'] && a['Namespace'] == option['Namespace']}.shift
            q.default = setting['Value'] unless setting.nil?
            q.readline = true
            if option['ValueType'] == 'List'
              q.gather = ''
            end

          }
          #pp value
        }
      end

=end

    end
  end
end