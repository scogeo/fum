module Fum
  module Commands
    class Status < Fum::Command
      include Fum::DNS

      def banner
        super << "<stage>"
      end

      def add_options(opts, options)
        opts.separator ""
        opts.separator "<stage> is a stage defined in the specified fum file."
        opts.separator ""
        opts.separator "options are:"
      end

      def execute(options, args)
        stage_name = stage_name_from_args(args)
        stage_decl = stage(stage_name)

        analyzer = StageAnalyzer.new(stage_decl)
        analyzer.analyze(options)

        envs = analyzer.env_map.values

        unless envs.empty?
          envs.each { |env|
            status = ""
            status += "#{env[:env].status}, " unless env[:env].status == 'Ready'
            status += "#{env[:env].health}, " unless env[:env].health == 'Grey'
            status += env[:state].to_s
            puts "#{env[:env].name} (#{status})"
          }
        else
          puts "No environments found for stage #{stage_name}."
        end

      end

    end
  end
end