module Fum
  module Commands
    class Terminate < Fum::Command

      def banner
        super << "<stage>"
      end

      def add_options(opts, options)

        options[:all] = false

        opts.separator ""
        opts.separator "options are:"

        opts.on('--all',
                "Terminate all environments for this stage (use with caution).") { |value| options[:all] = true }
      end

      #
      def execute(options, args)
        stage_name = stage_name_from_args(args)
        stage_decl = stage(stage_name)

        analyzer = StageAnalyzer.new(stage_decl)
        analyzer.analyze(options)

        env_info = analyzer.env_map.values

        targets = []

        if options[:all]
          targets = env_info.map { |e| e[:env] }
        else
          targets = env_info.select { |e| e[:state] == :inactive }.map { |e| e[:env] }
        end

        if targets.length > 0
          targets.each { |target|
            if target.ready?
              puts "Terminating inactive environment #{target.name}."
              target.destroy unless Fum.noop
            end

          }
        else
          puts "No environments to terminate."
        end

      end

    end
  end
end