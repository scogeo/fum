
module Fum
  module Lang
    class FumFile

      require 'fum/lang/stage'

      attr_accessor :name, :global_settings

      def initialize
        @global_settings = {}
      end

      def self.load(filename)
        file = self.new
        file.instance_eval(File.read(filename), filename)
        file
      end

      def application_name(name)
        @name = name
      end

      def settings(value)
        @global_settings = value
      end

      def stages
        @stages ||= {}
      end

      def stage(*args, &block)
        stage = Fum::Lang::Stage.new(*args, &block)
        stages[stage.id] = stage
      end
    end
  end
end