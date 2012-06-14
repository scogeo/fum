module Fum
  module Commands
    class Template
      class List < Fum::Commands::Template::Command

        def execute(options, args)
          templates = Fog::AWS[:beanstalk].templates

          templates = templates.sort_by { |a| [ a.application_name, a.name ] }

          table = []
          templates.each { |template|
            table << {
                'name' => template.name,
                'application' => template.application_name,
                'description' => template.description,
                'created' => template.created_at,
                'updated' => template.updated_at
            }
          }
          Formatador.display_compact_table(table, %w(application name description created updated))
        end

      end

    end


  end
end