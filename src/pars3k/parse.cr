require "./parser"
require "./parse_result"

module Pars3k
  # Tools for creating commonly useful parser instances.
  module Parse
    extend self

    # Always succeeds with *value* and does not consume any input.
    def const(value : T) : Parser(T) forall T
      Parser(T).const value
    end

    # Parser that succeeds with *value* if *block* evaluates to true when passed
    # the value.
    #
    # In most cases this should not be used externally and is instead a tool for
    # composing parsers.
    def cond(value : T, &block : T -> Bool) : Parser(T) forall T
      Parser(T).new do |context|
        if block.call value
          ParseResult(T).new value, context
        else
          ParseResult(T).error "unsatisfied predicate, got '#{value}'", context
        end
      end
    end

    # Parser that return the context head if it satisfies *block*.
    def char_if(&block : Char -> Bool) : Parser(Char)
      Parser.char.bind do |value|
        cond value, &block
      end
    end

    # :ditto:
    def byte_if(&block : UInt8 -> Bool) : Parser(UInt8)
      Parser.byte.bind do |value|
        cond value, &block
      end
    end

    # Parser that tests equivalence to *value* at the parse head, or fails.
    def eq(value : T) : Parser(T) forall T
      Parser.head.bind do |head|
        cond value, &.===(head)
      end
    end

    # Parser that matches for a specific *char* at the parse head.
    def char(char : Char) : Parser(Char)
      char_if &.==(char)
    end

    # Parser that matches for a specific *byte* at the parse head.
    def byte(byte : UInt8) : Parser(UInt8)
      byte_if &.==(byte)
    end

    # Creates a `Parser(String)` that looks at the current parse position
    # expects the array of characters in the string `s` (`s.chars`) to be
    # consecutively present.
    def string(string : String) : Parser(String)
      case string.size
      when 0
        const ""
      when 1
        char(string[0]).map &.to_s
      else
        string.each_char.map(&->char(Char)).reduce do |a, b|
          a >> b
        end >> const string
      end
    end

    # Creates a `Parser(Char)` that looks at the current parse position and
    # expects the current character to be present in the string `s`.
    def one_char_of(string : String) : Parser(Char)
      raise ArgumentError.new "string is empty" if string.empty?
      char_if &.in?(string)
    end

    # Functions identically to `Parse.one_char_of`, but reverses the expected
    # input. If the current character is present in `s`, then the parse fails.
    def no_char_of(string : String) : Parser(Char)
      char_if &.in?(string).!
    end

    # Creates a `Parser(Array(T))` that will continue to parse with *parser*
    # delimited by *delimter* until an error with either occurs.
    def list(item : Parser(A), delimiter : Parser(B)) : Parser(Array(A)) forall A, B
      empty_list = const [] of A
      non_empty_list(item, delimiter) | empty_list
    end

    def non_empty_list(item : Parser(A), delimiter : Parser(B)) : Parser(Array(A)) forall A, B
      singleton = item * 1
      plural = ((item << delimiter) * (1..) + item).map { |(xs, x)| xs << x }
      plural | singleton
    end

    # Parses a character of the lowercase alphabet.
    def alpha_lower
      char_if &.lowercase?
    end

    # Parses a character of the uppercase alphabet.
    def alpha_upper
      char_if &.uppercase?
    end

    # Parses a character in the alphabet regardless of case.
    def alpha
      char_if &.letter?
    end

    def alphanumeric
      char_if &.alphanumeric?
    end

    # Parses a full word of at least one character.
    def word
      (alphanumeric * (1..)).map &.join
    end

    def whitespace
      char_if &.whitespace?
    end

    # Parses a digit as a character.
    def digit
      char_if &.number?
    end

    # Parses an integer as a String
    def integer
      (digit * (1..)).map &.join
    end

    # Parsed an integer as an `Int32`
    def i_32
      (digit * (1..)).map do |digits|
        digits.reduce(0) { |accum, d| accum * 10 + t.to_i }
      end
    end
  end
end
