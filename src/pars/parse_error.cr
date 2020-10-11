module Pars
  # A struct containing information about a parse error.
  struct ParseError
    getter context
    getter message

    def initialize(@message : String, @context : ParseContext)
    end

    def to_s(io : IO)
      io << '('
      io << context
      io << ')'
      io << ' '
      io << message
    end
  end
end
