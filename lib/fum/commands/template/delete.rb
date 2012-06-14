module Fum
  module Commands
    class Template
      class Delete < Fum::Commands::Template::Command

        def banner
          super << "{template}"
        end

        def execute(options, args)
          template_name = args.shift
          die "No template specified." if template_name.nil?
          template = template(template_name)
          template.destroy
          puts "Deleted template #{template.name}."
        end
      end

    end

  end
end