module Fum
  module Commands
    class Launch < Fum::Command
      include Fum::DNS

      def banner
        super << "<stage>"
      end

      def add_options(opts, options)

        options[:no_dns] = false

        opts.separator ""
        opts.separator "options are:"

        opts.on('--version LABEL', '-v LABEL',
                "Launch the specified version") { |value| options[:version_label] = value }
        opts.on('--no-dns', '-n',
                "Launch, but do not change any DNS records") { |value| options[:no_dns] = true }
        opts.on('--create', '-c',
                "Create application if it does not exist") { |value| options[:create] = true }
      end

      def execute(options, args)
        stage_name = stage_name_from_args(args)
        stage_decl = stage(stage_name)

        if Fum.verbose
          puts "Verifying application '#{application_name}' exists in AWS."
        end

        beanstalk = Fog::AWS[:beanstalk]

        beanstalk_app = beanstalk.applications.get(application_name)

        if beanstalk_app.nil?
          if options[:create]
            beanstalk_app = beanstalk.applications.create(:name => application_name)
            beanstalk.versions.create({
                                          :application_name => application_name,
                                          :label => 'Sample'
                                      })
          else
            die "Could not find app '#{application_name}' in AWS account."
          end

        end

        env_opt = {
            :application_name => application_name,
            :name => stage_decl.environment_name
        }
        env_opt[:template_name] = stage_decl.template_name unless stage_decl.template_name.nil?
        env_opt[:solution_stack_name] = stage_decl.solution_stack_name unless stage_decl.solution_stack_name.nil?
        env_opt[:description] = stage_decl.env_description unless stage_decl.env_description.nil?

        set_option_settings(stage_decl, env_opt, options)
        set_version(stage_decl, env_opt, options)
        swap_env = set_cname(stage_decl, env_opt, options)

        if Fum.verbose || Fum.noop
          puts "Launching an environment named '#{stage_decl.environment_name}'"
        end

        begin
          new_env = beanstalk.environments.create(env_opt) unless Fum.noop
        rescue Exception => e
          die "Problem creating environment: #{e.to_s}"
        end

        puts "Launched environment '#{stage_decl.environment_name}'."

        puts "Waiting for environment to become ready..."

        new_env.wait_for { ready? } unless Fum.noop

        puts "New environment is ready."

        return if Fum.noop

        puts "Waiting for application to start..."

        sleep 120 unless Fum.noop

        puts "Waiting for environment health status..."

        # Wait for health to change from Grey to a known state
        new_env.wait_for { health != 'Grey' } unless Fum.noop
        if (Fum.noop || new_env.health == "Green")
          puts "New environment is healthy and available at #{new_env.cname}."
          update_zones(stage_decl, new_env, options) unless options[:no_dns]
        else
          puts "Environment launched, but health status is #{new_env.health}."
          puts "DNS Records will not be updated."
        end

        if swap_env
          puts "Swapping environment CNAMES with #{swap_env.name}"
          new_env.swap_cnames(swap_env)
        end
      end

      def set_option_settings(stage_decl, env_opt, options)
        merged_settings = application_settings

        stage_decl.stage_settings.each do |key, value|
          namespaceValues = merged_settings[key]
          if namespaceValues.nil?
            namespaceValues = {}
            merged_settings[key] = namespaceValues
          end
          namespaceValues.merge!(value)
        end

        # Flatten settings into an array
        flattened_settings = []
        merged_settings.each do |namespace, hashedValues|
          hashedValues.each do |option, value|
            flattened_settings << {
                "Namespace" => namespace,
                "OptionName" => option,
                "Value" => value
            }
          end
        end

        env_opt[:option_settings] = flattened_settings

      end

      def set_version(stage_decl, env_opt, options)
        version_label = stage_decl.version_label
        return nil if version_label.nil?

        if version_label.is_a?(String)
          env_opt[:version_label] = version_label
          puts "Using verison label #{version_label}"
        elsif version_label.is_a?(Hash) && version_label.has_key?(:from_stage)
          from_stage = version_label[:from_stage]
          from_stage_decl = stage(from_stage)
          analyzer = StageAnalyzer.new(from_stage_decl)
          analyzer.analyze(options)
          active = analyzer.active
          die "Cannot determine version to launch. No active environment for stage '#{from_stage}' specified." if active.nil?
          env_opt[:version_label] = active.version_label
          puts "Using version #{active.version_label} from stage #{from_stage}."
        else
          "Unknown version label #{version_label.inspect}"
        end

      end

      def set_cname(stage_decl, env_opt, options)
        cname_prefix = stage_decl.cname
        if cname_prefix
          # Set the prefix
          if stage_decl.swap_cnames
            analyzer = StageAnalyzer.new(stage_decl)
            analyzer.analyze(options)
            active = analyzer.active
            if active
              puts "Found an active environment (#{active.name}) with existing cname, will swap after creation."
              return active
            else
              env_opt[:cname_prefix] = cname_prefix
            end
          else
            env_opt[:cname_prefix] = cname_prefix
          end
        end
        nil
      end
    end
  end
end