module Fum
  module Lang
    class Stage

      require 'fum/lang/zone'

      attr_accessor :zones, :environment_name, :id, :cname, :swap_cnames, :template_name, :solution_stack_name, :version_label
      attr_accessor :env_description

      def initialize(id, &block)
        @zones = []
        @environment_name = id.to_s
        @id = id.to_s
        @swap_cnames = false

        if block_given?
          if block.arity == 1
            yield self
          else
            instance_eval &block
          end
        end
      end

      def timestamp_name(prefix)
        raise ArgumentError, "Prefix must be less than 15" unless prefix.length < 15 && prefix.length > 1
        return "#{prefix}-#{Time.now.to_i.to_s(16)}"
      end

      def timestamp_name_matcher(prefix)
        raise ArgumentError, "Prefix must be less than 15" unless prefix.length < 15 && prefix.length > 1
        /#{prefix}-[a-z0-9]{8}/
      end

      def zone(*args, &block)
        @zones << Zone.new(*args, &block)
      end

      def template(arg, &block)
        @template_name = arg
      end

      def name(arg)
        @environment_name = arg
      end

      def matcher(arg)
        @matcher = arg
      end

      def version(arg)
        @version_label = arg
      end

      def description(value)
        @env_description = value
      end

      def solution_stack(name, &block)
        @solution_stack_name = name
      end

      def cname_prefix(name, opts = {})
        @cname = name
        if opts[:swap]
          @swap_cnames = true
        end
      end

      # Returns true if environment matches the matcher for this stage
      def matches?(env)
        if @matcher
          if @matcher.is_a?(Regexp)
            return env.name =~ @matcher
          else
            return env.name == @matcher
          end
        else
          return env.name == @environment_name
        end
        false
      end

    end
  end
end
