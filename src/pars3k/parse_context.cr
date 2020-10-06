module Pars3k
  # A struct containing information about the current Parser's context.
  # Used to chain Parsers together and retain input position.
  struct ParseContext
    getter parsing
    getter position

    def initialize(@parsing : String, @position : Int32 = 0)
    end

    def next(offset = 1)
      ParseContext.new(@parsing, @position + offset)
    end

    def set_position(pos)
      @position = pos
    end
  end
end
