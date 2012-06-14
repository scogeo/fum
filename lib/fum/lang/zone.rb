module Fum
  module Lang
    class Zone

      attr_accessor :name, :records

      def initialize(name, &block)
        @name = name
        @records = []

        if block_given?
          if block.arity == 1
            yield self
          else
            instance_eval &block
          end
        end
      end

      def elb_alias(name, opts = {})
        @records << { :name => name, :type => 'A', :target => :elb, :options => opts}
      end

      def elb_cname(name, opts = {})
        @records << { :name => name, :type => 'CNAME', :target =>:elb, :options => opts}
      end

      def cname(name, opts = {})
        @records << { :name => name, :type => 'CNAME', :target =>:env, :options => opts}
      end
    end
  end
end