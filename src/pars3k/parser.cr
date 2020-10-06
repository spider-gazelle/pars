require "./parse_result"
require "./parse_context"

module Pars3k
  class Parser(T)
    private getter block

    def initialize(&block : ParseContext -> ParseResult(T))
      @block = block
    end

    # Parses the input string `input` given the parser's logic provided by its
    # block at definition.
    def parse(input : String) : (T | ParseError)
      context = ParseContext.new input
      result = @block.call context
      result.value
    end

    # Transforms the result of the parser such that, when the parser runs, the
    # output value becomes a different value.
    #
    # For example, if you took a `Parser(Char)` and wanted to transform it to a
    # `Parser(String)` by `Char#to_s`, then you could use
    # `char_parser.transform &.to_s`.
    #
    # It is similar to a map method on arrays from other languages.
    def transform(&new_block : T -> B) : Parser(B) forall B
      Parser(B).new do |context|
        result = @block.call context
        if result.errored
          ParseResult(B).error result.definite_error
        else
          begin
            ParseResult(B).new new_block.call(result.definite_value), result.context
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
    def sequence(&new_block : T -> Parser(B)) : Parser(B) forall B
      Parser(B).new do |context|
        result = @block.call context
        if result.errored
          ParseResult(B).error result.definite_error
        else
          next_parser = new_block.call result.definite_value
          next_parser.block.call result.context
        end
      end
    end

    # Sequences `self` with another parser of the same type.
    def +(other : Parser(B)) : Parser(B) forall B
      sequence { |_| other }
    end

    # Sequences the current parser with another parser, and disregards the other
    # parser's result, but ensures the two succeed.
    def <<(other : Parser(B)) : Parser(T) forall B
      Parser(T).new do |context|
        result = @block.call context
        if result.errored
          result
        else
          new_result = other.block.call result.context
          if new_result.errored
            ParseResult(T).error new_result.definite_error
          else
            result.set_context_position new_result.context.position
            result
          end
        end
      end
    end

    # Sequences the current parser with another parser, and disregards the
    # original parser's result, but ensures the two succeed.
    def >>(other : Parser(B)) : Parser(B) forall B
      Parser(B).new do |context|
        result = @block.call context
        if result.errored
          ParseResult(B).error result.definite_error
        else
          new_result = other.block.call result.context
          new_result
        end
      end
    end

    # Given `A | B`, creates a new parser that succeeds when A succeeds or B
    # succeeds. Checks A first, doesn't check B if A succeeds.
    def |(other : Parser(T)) : Parser(T)
      Parser(T).new do |context|
        result = @block.call context
        if result.errored
          other.block.call context
        else
          result
        end
      end
    end

    # Given `A / B`, creates a new parser that succeeds when A succeeds or B
    # succeeds. Checks A first, doesn't check B if A succeeds. Ignores type
    # differences, gives union type.
    def /(other : Parser(B)) : Parser(T | B) forall B
      Parser(T | B).new do |context|
        result = @block.call context
        if result.errored
          new_result = other.block.call result.context
          if new_result.errored
            ParseResult(T | B).error new_result.definite_error
          else
            ParseResult(T | B).new new_result.definite_value, new_result.context
          end
        else
          ParseResult(T | B).new result.definite_value, result.context
        end
      end
    end
  end
end
