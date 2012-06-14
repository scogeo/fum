module Fum
  module Commands
    class Template
      class Create < Fum::Commands::Template::Command

        def banner
          super << "{template-name}"
        end

        def add_options(opts, options)
          options[:json] = false

          opts.separator ""
          opts.separator "options are:"

          opts.on('--description DESCRIPTION', '-d DESCRIPTION',
                  "Description of new template.") { |value| options[:description] = value }

          opts.on('--stack STACK', '-s STACK',
                  "Create template from the specified solution stack.") { |value| options[:stack] = value }

          opts.on('--from-template TEMPLATE',
                  "Create template from the specified template.") { |value| options[:from_template] = value }

          opts.on('--from-application APPNAME',
                  "Use the specified application name for the source template.") { |value| options[:from_application] = value }

        end

        def execute(options, args)
          template_name = args.shift

          options[:application] ||= application_name

          die "Must specify application name " if options[:application].nil?

          create_opts = {
              :name => template_name,
              :application_name => options[:application]
          }

          create_opts[:solution_stack_name] = options[:stack] if options[:stack]
          create_opts[:description] = options[:description] unless options[:description].nil?
          create_opts[:source_configuration] = {
              'ApplicationName' => options[:from_application].nil? ? options[:application] : options[:from_application],
              'TemplateName' => options[:from_template]
          } if options[:from_template]

          begin
            template = Fog::AWS[:beanstalk].templates.create(create_opts)
            puts "Created template #{template.name}"
          rescue Fog::AWS::ElasticBeanstalk::InvalidParameterError => ex
            die ex.message
          end

        end
      end

    end

  end
end