require "./parse_result"
require "./parse_context"

module Pars
  class Parser(T)
    # Creates a `Parser` that always succeeds with *value*.
    def self.const(value : T)
      new do |context|
        ParseResult(T).new value, context
      end
    end

    # Creates a `Parser` that always fails with *message*.
    def self.fail(message : String)
      new do |context|
        ParseResult(T).error message, context
      end
    end

    {% for item in [:head, :char, :byte] %}
      # Creates a `Parser` that consumes the parse head, or fails if the end of
      # input has been reached.
      def self.{{item.id}}
        new do |context|
          if context.exhausted?
            ParseResult(typeof(context.{{item.id}})).error "input ended", context
          else
            ParseResult(typeof(context.{{item.id}})).new context.{{item.id}}, context.next
          end
        end
      end
    {% end %}

    def initialize(&block : ParseContext -> ParseResult(T))
      @block = block
    end

    # Parses the input string `input` given the parser's logic provided by its
    # block at definition.
    def parse(input) : (T | ParseError)
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
    def map(&block : T -> B) : Parser(B) forall B
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
    def bind(&block : T -> Parser(B)) : Parser(B) forall B
      Parser(B).new do |context|
        result = run context
        if result.errored
          ParseResult(B).error result.error!
        else
          other = block.call result.value!
          other_result = other.run result.context
          if other_result.errored
            ParseResult(B).error other_result.error!.message, context
          else
            other_result
          end
        end
      end
    end

    # Sequences `self` with *other*, providing a new Parser that returns the
    # results as a Tuple.
    #
    # If multiple parsers are chained, the results are flattened.
    def +(other : Parser(B)) forall B
      self.bind do |a|
        other.bind do |b|
          {% if T.name.starts_with? "Tuple(" %}
            Parser(typeof(a + {b})).const Tuple.new *a, b
          {% else %}
            Parser({T, B}).const({a, b})
          {% end %}
        end
      end
    end

    # Sequences the current parser with another parser, and disregards the other
    # parser's result, but ensures the two succeed.
    def <<(other : Parser(B)) : Parser(T) forall B
      Parser(T).new do |context|
        result = run context
        if result.errored
          result
        else
          other_result = other.run result.context
          if other_result.errored
            ParseResult(T).error other_result.error!.message, context
          else
            ParseResult(T).new result.value!, other_result.context
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
          other_result = other.run result.context
          if other_result.errored
            ParseResult(B).error other_result.error!.message, context
          else
            other_result
          end
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
          new_result = other.run context
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

    # Creates a new `Parser(T)` that fails with *message* if `self` is
    # unsuccessful.
    #
    # This can be used to provide a custom error message when chaining parsers.
    def |(message : String) : Parser(T)
      Parser(T).new do |context|
        result = run context
        if result.errored
          ParseResult(T).error message, result.context
        else
          result
        end
      end
    end

    # Given `A & B`, creates a parser that succeeds when both A and B succeed
    # for the same input.
    def &(other : Parser(B)) : Parser(B) forall B
      Parser(B).new do |context|
        result = run context
        if result.errored
          ParseResult(B).error result.error!
        else
          other.run context
        end
      end
    end

    # Given `A ^ B`, creates a parser that succeeds if A or B succeed
    # exclusively for the same input.
    #
    # If both succeed, the parser will fail.
    def ^(other : Parser(B)) : Parser(T | B) forall B
      Parser(T | B).new do |context|
        result = run context
        other_result = other.run context
        if result.errored && other_result.errored
          ParseResult(T | B).error other_result.error!
        elsif result.errored
          ParseResult(T | B).new other_result.value!, other_result.context
        elsif other_result.errored
          ParseResult(T | B).new result.value!, result.context
        else
          ParseResult(T | B).error "expected only one parser to succeed", context
        end
      end
    end

    # Creates a new parser that repeats `self` exactly *count* times.
    def *(count : Int) : Parser(Array(T))
      case count
      when .< 0
        raise ArgumentError.new "cannot match less than zero times"
      when .== 0
        Parser.const [] of T
      else
        self * (count..count)
      end
    end

    # Creates a new parser that repeats `self` continuously up to *range.end*
    # times. If *range* is not bounded it will continue to repeat until failing.
    def *(range : Range(Int, Int) | Range(Int, Nil)) : Parser(Array(T))
      Parser(Array(T)).new do |context|
        result = run context
        if result.errored && !range.includes? 0
          next ParseResult(Array(T)).error result.error!
        end

        results = [] of T
        if (max = range.end)
          # Bounded range
          max -= 1 if range.excludes_end?
          while !result.errored
            results << result.value!
            break if results.size >= max
            result = run result.context
          end
        else
          # Unbounded - parse until error
          while !result.errored
            results << result.value!
            result = run result.context
          end
        end

        unless range.includes? results.size
          next ParseResult(Array(T)).error "expected #{range} parses, got #{results.size} parses", result.context
        end

        ParseResult.new results, result.context
      end
    end
  end
end
