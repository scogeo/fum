module Fum

  class FatalError < RuntimeError
  end
  # Fum module singleton methods.
  #
  class << self

    def verbose
      @verbose ||= false
    end

    def verbose=(value)
      @verbose = value
    end

    def noop
      @noop ||= false
    end

    def noop=(value)
      @noop = value
    end

    def die(msg)
      raise FatalError.new msg
    end

  end



end