module Fum
  module Commands
    class Template
      class Update < Fum::Commands::Template::Command

        def banner
          super << "{template}"
        end

        def add_options(opts, options)
          options[:json] = false

          opts.separator ""
          opts.separator "options are:"

          opts.on('--json FILE', '-j FILE',
                  "Settings file in json format to update.") { |value| options[:json] = value }

          opts.on('--description DESCRIPTION', '-d DESCRIPTION',
                  "Description of new template.") { |value| options[:description] = value }

        end

        def execute(options, args)

          template_name = args.shift

          options[:application] ||= application_name

          die "Must specify application name " if options[:application].nil?

          template = template(template_name)

          settings = []
          if options[:json]
            settings = JSON.parse(File.read(options[:json]))
            # TODO add some sanity checks, verify array of hashes, etc.
          end
          new_attributes = {
              :option_settings => settings
          }
          new_attributes[:description] = options[:description] unless options[:description].nil?

          begin
            template.modify(new_attributes)
            puts "Updated template #{template.name}"
          rescue Fog::AWS::ElasticBeanstalk::InvalidParameterError => ex
            die "Exception during update #{ex}"
          end

        end
      end

    end

  end
end