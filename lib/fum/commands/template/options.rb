module Fum
  module Commands
    class Template
      class Options < Fum::Commands::Template::Command

        def banner
          super << "[template-name]"
        end

        def add_options(opts, options)
          options[:json] = false

          opts.separator ""
          opts.separator "options are:"

          opts.on('--json', '-j',
                  "Output in json format.") { |value| options[:json] = true }
          opts.on('--stack STACK', '-s STACK',
                  "Print options for specified solution stack, rather than template.") { |value| options[:stack] = value }
        end

        def execute(options, args)
          if options[:stack]
            begin
              values = Fog::AWS[:beanstalk].describe_configuration_options('SolutionStackName' => options[:stack])
              values = values.body['DescribeConfigurationOptionsResult']['Options']
            rescue Fog::AWS::ElasticBeanstalk::InvalidParameterError => ex
              die ex.message
            end
          else
            t = template(args.shift)
            values = t.options
          end
          print_options(values, options)
        end

        def print_options(values, options)
          values = values.sort_by { |a| [ a["Namespace"], a["Name"]]}

          if options[:json]
            puts JSON.pretty_generate(values)
          else
            values.each { |value|
              constraints = ''
              if value['MinValue'] && value['MaxValue']
                constraints = "Range(#{value['MinValue']}-#{value['MaxValue']})"
              elsif value['ValueOptions']
                type = value['ValueType'] == 'List' ? 'List' : 'Scalar'
                constraints = "#{type}(#{value['ValueOptions'].join(', ')})"
              elsif value['Regex']
                constraints = "Regex(#{value['Regex']['Label']} = #{value['Regex']['Pattern']})"
              elsif value['ValueType'] == 'Boolean'
                constraints = "Boolean(true, false)"
              end

              if value['MaxLength']
                max_length_constraint = "MaxLength(#{value['MaxLength']})"
                constraints += ', ' unless constraints.empty?
                constraints += max_length_constraint
              end
              value['Constraints'] = constraints
            }
            Formatador.display_compact_table(values, %w(Namespace Name DefaultValue Constraints))
          end

        end

      end

    end

  end
end