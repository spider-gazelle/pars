require "./parse_error"
require "./parse_context"

module Pars3k
  # ParseResult(T) is a result of a parsed Parser with return type T.
  # If the parse errored, then `ParseResult(T)#errored` will be true.
  # Otherwise, you can get a value of type `(T | ParseError)` with `ParseResult(T).value`.
  # If you are absolutely positive the parse did NOT error (e.g. `!ParseResult(T).errored`),
  # then you can acquire the value of type `T` with `ParseResult(T).definite_value`.
  struct ParseResult(T)
    def self.error(e : ParseError)
      inst = ParseResult(T).allocate
      inst.initialize_as_error e
      inst
    end

    def self.error(message : String, context : ParseContext)
      ParseResult(T).error ParseError.new message, context
    end

    @errored = uninitialized Bool
    @error = uninitialized ParseError
    @context = uninitialized ParseContext

    getter errored
    getter context

    def initialize(@value : T, @context)
      @errored = false
    end

    def initialize_as_error(e : ParseError)
      @errored = true
      @error = e
      @context = e.context
    end

    def set_context_position(pos)
      @context.set_position pos
    end

    def error
      errored ? @error : Nil
    end

    def value
      errored ? @error : @value
    end

    def definite_value
      @value
    end

    def definite_error
      @error
    end
  end
end
