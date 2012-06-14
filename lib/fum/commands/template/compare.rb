module Fum
  module Commands
    class Template
      class Compare < Fum::Commands::Template::Command

        def banner
          super << "{template1} {template2} ..."
        end

        def execute(options, args)
          templates = Hash.new{ |h,k| h[k] = Hash.new(&h.default_proc) }
          table = []
          all_names = {}
          columns = %w(Namespace Name)

          args.each { |name|
            template = template(name)
            settings = template.option_settings

            settings.each { |setting|
              namespace = setting['Namespace']
              option_name = setting['OptionName']

              # Maintain a list of all unique namespace/name combinations
              names = all_names[setting['Namespace']] || []
              names << setting['OptionName'] unless names.include?(setting['OptionName'])
              all_names[setting['Namespace']] = names

              # Build Index for comparison later
              templates[name][namespace][option_name] = setting['Value']
            }

            columns << name
          }

          all_names.each { |namespace, option_names|

            option_names.each { |option_name|
              line = {
                  'Namespace' => namespace,
                  'Name' => option_name
              }

              values = {}
              prev_value = :init
              values_differ = false

              args.each { |template_name|
                value = templates[template_name][namespace][option_name]

                if !values_differ && prev_value != :init
                  values_differ = value != prev_value
                  prev_value = value
                end
                prev_value = value if prev_value == :init

                values[template_name] = value
              }

              if values_differ
                values.each { |key, value|
                  values[key] = "[bold]#{value.to_s}[/]"
                }
              end

              table << line.merge(values)
            }
          }

          table = table.sort_by { |a| [ a["Namespace"], a["Name"]]}

          Formatador.display_compact_table(table, columns)


        end
      end

    end

  end
end