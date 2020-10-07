module Pars3k
  # A struct containing information about a parsing context. Used to chain
  # Parsers together and retain input position.
  struct ParseContext
    def initialize(@input : String, @pos : Int32 = 0)
    end

    property pos

    def next(offset = 1)
      ParseContext.new(@input, pos + offset)
    end

    def exhausted?
      pos >= @input.size
    end

    def peek
      @input[pos]
    end
  end
end
