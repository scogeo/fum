module Fum
  module Commands
    class List < Fum::Command
      include Fum::DNS

      def banner
        super << "<object-type>"
      end

      def add_options(opts, options)
        opts.separator "<object-type> is one of stacks, applications, environments, stages, templates, or versions."
        opts.separator "options are:"
      end

      def execute(options, args)
        beanstalk = Fog::AWS[:beanstalk]
        object = args.shift
        case object
          when "stacks"
            beanstalk.solution_stacks.each { |stack|
              puts stack["SolutionStackName"]
            }
          when "app", "apps", "applications"
            beanstalk.applications.each { |app|
              puts app.name
            }
          when "env", "envs", "environments"
            beanstalk.environments.each { |env|
              puts env.name
            }
          when "stages"
            @command_manager.definitions.stages.each_value { |stage|
              puts stage.id
            }
          when "templates"
            beanstalk.templates.each { |template|
              puts template.name
            }
          when "versions"
            beanstalk.versions.each { |version|
              puts version.label
            }
          when "help", nil
            puts help
          else
            die "Unknown object to list '#{object}'."
        end
      end

    end
  end
end