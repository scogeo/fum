module Fum
  module Commands
    class Repair < Fum::Command
      include Fum::DNS

      def banner
        super << "<stage>"
      end

      #
      #
      def execute(options, args)
        stage_name = stage_name_from_args(args)
        stage_decl = stage(stage_name)

        analyzer = StageAnalyzer.new(stage_decl)
        analyzer.analyze(options)

        degraded = analyzer.env_map.each_value.select { |env| env[:state] == :degraded }

        if degraded.length == 1
          degraded = degraded.shift
          puts "Repairing environment #{degraded[:env].name}."
          update_zones(stage_decl, degraded[:env], options)
          puts "Repair complete."
        else
          puts "No degraded environments to repair."
        end

      end

    end
  end
end