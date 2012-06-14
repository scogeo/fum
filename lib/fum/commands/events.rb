module Fum
  module Commands
    class Events < Fum::Command

      def add_options(opts, options)
        opts.separator ""
        opts.separator "Note: when run with a fum definition file, the application name is taken from the file's definition."
        opts.separator ""
        opts.separator "options are:"

        opts.on('--number N', '-n N', Integer, "Number of events to show") { |value| options[:number] = value }
        opts.on('--application APP', '-a APP',
                "Show events only for the specified application") { |value| options[:application] = value }
        opts.on('--environment ENV', '-e ENV',
                "Show events associated with the specified environment name or id") { |value| options[:environment] = value }
        opts.on('--severity LEVEL', '-s LEVEL',
                "Limit events to severity or higher") { |value| options[:severity] = value }
        opts.on('--version LABEL', '-v LEVEL',
                "Show events for the specified version label") { |value| options[:version_label] = value }
      end

      def execute(options, args)
        beanstalk = Fog::AWS[:beanstalk]

        # Use the application name from the fum definition if present.
        options[:application] ||= application_name

        filters = {
            'MaxRecords' => options[:number],
            'ApplicationName' => options[:application],
            'VersionLabel' => options[:version_label]
        }
        filters['Severity'] = options[:severity].upcase unless options[:severity].nil?

        if options[:environment] && options[:environment].match(/e-[a-zA-Z0-9]{10}/)
          filters['EnvironmentId'] = options[:environment]
        else
          filters['EnvironmentName'] = options[:environment]
        end

        filters = filters.delete_if { |key, value| value.nil? }

        events = beanstalk.events.all(filters).reverse

        # Beanstalk seems to return an extra item
        events.shift

        events.each { |event|
          app = event.application_name
          if event.environment_name
            app += "(#{event.environment_name})"
          elsif event.version_label
            app += "(#{event.version_label})"
          elsif event.template_name
            app += "(#{event.template_name})"
          end

          puts "#{event.date.strftime('%b %d %H:%M:%S')} #{app} #{event.severity} \"#{event.message}\""
        }

      end

    end


  end
end