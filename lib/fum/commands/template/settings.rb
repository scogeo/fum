module Fum
  module Commands
    class Template
      class Settings < Fum::Commands::Template::Command

        def banner
          super << "{template-name}"
        end

        def add_options(opts, options)
          options[:json] = false

          opts.separator ""
          opts.separator "options are:"

          opts.on('--json', '-j',
                  "Output in json format.") { |value| options[:json] = true }
        end

        def execute(options, args)
          t = template(args.shift)
          values = t.option_settings
          values = values.sort_by { |a| [ a["Namespace"], a["OptionName"]]}
          if options[:json]
            # Prune nil values in JSON, or we can't update from JSON
            values = values.select { |v| !v["Value"].nil? }
            puts JSON.pretty_generate(values)
          else
            Formatador.display_compact_table(values, %w(Namespace OptionName Value))
          end
        end
      end

    end

  end
end