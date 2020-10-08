module Pars3k
  # A struct containing information about a parsing context. Used to chain
  # Parsers together and retain input position.
  struct ParseContext
    def initialize(@input : String, @pos : Int32 = 0)
    end

    # The input the parser is working across.
    getter input

    # The correct parse offset within *input*.
    getter pos

    # Creates a new context at the next parse position.
    def next(offset = 1)
      ParseContext.new(input, pos + offset)
    end

    # `true` if all of the input has been consumed.
    def exhausted?
      pos >= input.size
    end

    # The value at the current parse position.
    def head
      input[pos]
    end
  end
end
