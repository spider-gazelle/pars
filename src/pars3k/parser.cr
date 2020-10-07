require "./parse_result"
require "./parse_context"

module Pars3k
  class Parser(T)
    def initialize(&block : ParseContext -> ParseResult(T))
      @block = block
    end

    # Parses the input string `input` given the parser's logic provided by its
    # block at definition.
    def parse(input : String) : (T | ParseError)
      context = ParseContext.new input
      run(context).value
    end

    # Runs `self` for a given *context*.
    def run(context : ParseContext) : ParseResult(T)
      @block.call context
    end

    # Transforms the result of the parser such that, when the parser runs, the
    # output value becomes a different value.
    #
    # For example, if you took a `Parser(Char)` and wanted to transform it to a
    # `Parser(String)` by `Char#to_s`, then you could use
    # `char_parser.transform &.to_s`.
    #
    # It is similar to a map method on arrays from other languages.
    def transform(&block : T -> B) : Parser(B) forall B
      Parser(B).new do |context|
        result = run context
        if result.errored
          ParseResult(B).error result.error!
        else
          begin
            ParseResult(B).new block.call(result.value!), result.context
          rescue e
            ParseResult(B).error e.message || e.to_s, result.context
          end
        end
      end
    end

    # Sequences `self` with another parser.
    #
    # Expects a block that receives the result of the current parser and returns
    # a new parser of any type.
    def sequence(&block : T -> Parser(B)) : Parser(B) forall B
      Parser(B).new do |context|
        result = run context
        if result.errored
          ParseResult(B).error result.error!
        else
          next_parser = block.call result.value!
          next_parser.run result.context
        end
      end
    end

    # Sequences `self` with another parser of the same type.
    def +(other : Parser(T)) : Parser(T)
      sequence { |_| other }
    end

    # Sequences the current parser with another parser, and disregards the other
    # parser's result, but ensures the two succeed.
    def <<(other : Parser(B)) : Parser(T) forall B
      Parser(T).new do |context|
        result = run context
        if result.errored
          result
        else
          new_result = other.run result.context
          if new_result.errored
            ParseResult(T).error new_result.error!
          else
            result.context.set_position new_result.context.position
            result
          end
        end
      end
    end

    # Sequences the current parser with another parser, and disregards the
    # original parser's result, but ensures the two succeed.
    def >>(other : Parser(B)) : Parser(B) forall B
      Parser(B).new do |context|
        result = run context
        if result.errored
          ParseResult(B).error result.error!
        else
          new_result = other.run result.context
          new_result
        end
      end
    end

    # Given `A | B`, creates a new parser that succeeds when A succeeds or B
    # succeeds. Checks A first, doesn't check B if A succeeds.
    def |(other : Parser(T)) : Parser(T)
      Parser(T).new do |context|
        result = run context
        if result.errored
          other.run context
        else
          result
        end
      end
    end

    # Given `A | B`, creates a new parser that succeeds when A succeeds or B
    # succeeds. Checks A first, doesn't check B if A succeeds. Ignores type
    # differences, gives union type.
    def |(other : Parser(B)) : Parser(T | B) forall B
      Parser(T | B).new do |context|
        result = run context
        if result.errored
          new_result = other.run result.context
          if new_result.errored
            ParseResult(T | B).error new_result.error!
          else
            ParseResult(T | B).new new_result.value!, new_result.context
          end
        else
          ParseResult(T | B).new result.value!, result.context
        end
      end
    end
  end
end
