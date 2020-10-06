module Pars3k
  # A struct containing information about a parse error.
  struct ParseError
    getter context
    getter message

    def initialize(@message : String, @context : ParseContext)
    end

    def to_s
      "(#{@context.parsing}:#{@context.position}) #{@message}"
    end

    def to_s(io : IO)
      io << to_s
    end
  end
end
