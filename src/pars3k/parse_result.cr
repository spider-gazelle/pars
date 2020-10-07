require "./parse_error"
require "./parse_context"

module Pars3k
  # ParseResult(T) is a result of a parsed Parser with return type T.
  struct ParseResult(T)
    # Creates an errored `ParseResult` that wraps *e*.
    def self.error(e : ParseError)
      inst = ParseResult(T).allocate
      inst.initialize_as_error e
      inst
    end

    # Creates an errored `ParseResult`.
    def self.error(message : String, context : ParseContext)
      ParseResult(T).error ParseError.new message, context
    end

    @errored = uninitialized Bool
    @error = uninitialized ParseError
    @context = uninitialized ParseContext

    getter errored
    getter context

    # Creates a new successful `ParseResult`.
    def initialize(@value : T, @context)
      @errored = false
    end

    # :nodoc:
    def initialize_as_error(e : ParseError)
      @errored = true
      @error = e
      @context = e.context
    end

    # Returns a `ParseError`, or nil if parsing was successful.
    def error? : ParseError?
      errored ? @error : Nil
    end

    # Returns the parsed value, or a `ParseError`.
    def value : T | ParseError
      errored ? @error : @value
    end

    # Directly access to parsed value.
    #
    # Note: this is unsafe and should only be used if `#errored == false`.
    def value! : T
      @value
    end

    # Directly access the `ParseError`.
    #
    # Note: this unsafe and should only be used if `#errored == true`.
    def error! : ParseError
      @error
    end
  end
end
