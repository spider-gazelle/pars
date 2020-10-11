module Pars
  # A struct containing information about a parsing context. Used to chain
  # Parsers together and retain input position.
  struct ParseContext
    def initialize(@input, @pos = 0)
    end

    # The input the parser is working across.
    getter input : String | Bytes

    # The correct parse offset within *input*.
    getter pos : Int32

    # Creates a new context at the next parse position.
    def next(offset = 1) : ParseContext
      ParseContext.new(input, pos + offset)
    end

    # `true` if all of the input has been consumed.
    def exhausted? : Bool
      pos >= input.size
    end

    # Provides the parse head as a `Char`.
    def char : Char
      if input.is_a? String
        input.as(String).char_at pos
      else
        input.as(Bytes)[pos].chr
      end
    end

    # Provides the parse head as a byte.
    def byte : UInt8
      if input.is_a? String
        input.as(String).byte_at pos
      else
        input.as(Bytes)[pos]
      end
    end

    # Provide the current parse head directly.
    def head : Char | UInt8
      input[pos]
    end
  end
end
