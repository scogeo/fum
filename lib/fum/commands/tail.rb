module Fum
  module Commands
    class Tail < Fum::Command

      def add_options(opts, options)

        opts.separator ""
        opts.separator "options are:"

        opts.on('--application APP', '-a APP',
                "Application name to pull logs from.") { |value| options[:application] = value }
        opts.on('--environment ENV', '-e ENV',
                "Environment name or if to pull logs from") { |value| options[:environment] = value }
        opts.on('--directory DIR', '-d DIR',
                "Output log files to the directory specified.") { |value| options[:directory] = value }
      end

      def execute(options, args)
        beanstalk = Fog::AWS[:beanstalk]

        die "Directory #{options[:directory]} does not exist" if options[:directory] && !File.directory?(options[:directory])

        # Use the application name from the fum definition if present.
        options[:application] ||= application_name

        request_opts = {
            'ApplicationName' => options[:application],
            'EnvironmentName' => options[:environment],
            'InfoType' => 'tail'
        }

        if options[:environment] && options[:environment].match(/e-[a-zA-Z0-9]{10}/)
          request_opts['EnvironmentId'] = options[:environment]
        else
          request_opts['EnvironmentName'] = options[:environment]
        end

        puts "Requesting logs for environment #{options[:environment]}" if options[:verbose]
        begin
          beanstalk.request_environment_info(request_opts)
        rescue Fog::AWS::ElasticBeanstalk::InvalidParameterError => ex
          die ex.message
        end

        begin
          files = Timeout::timeout(360) do
            # Sleep a few seconds
            sleep(5)
            begin
              puts "Retrieving logs for environment #{options[:environment]}" if options[:verbose]
              info = beanstalk.retrieve_environment_info(request_opts).body["RetrieveEnvironmentInfoResult"]["EnvironmentInfo"]
              puts "Logs not yet available, will try again in 10 seconds." if options[:verbose] && info.length == 0
            end while info.length == 0 && sleep(10)

            info = info.sort_by { |i| i['SampleTimestamp'] }.reverse
            instance_ids = []
            info = info.select { |i|
              seen = instance_ids.include?(i['Ec2InstanceId'])
              instance_ids << i['Ec2InstanceId']
              !seen
            }
          end
        rescue Timeout::Error
          die "Operation timed out, could not retrieve environment info."
        end


        require 'excon'
        files.each { |file|
          contents = Excon.get(file['Message']).body
          if options[:directory]
            filename = "#{file['Ec2InstanceId']}-#{file['SampleTimestamp'].strftime('%Y%m%dT%H%M')}.txt"
            file = File.join(File.expand_path(options[:directory]),filename)
            if File.exists?(file)
              puts "File already exists #{file}, will not overwrite."
              next
            end
            File.open(file, 'w') { |f|f.write(contents) }
            puts "Created file #{file}"
          else
            puts "##########################################"
            puts "# InstanceID #{file['Ec2InstanceId']}"
            puts "# Timestamp #{file['SampleTimestamp']}"
            puts "##########################################"
            puts contents
          end

        }

      end

    end


  end
end