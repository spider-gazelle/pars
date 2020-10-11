require "./parser"
require "./parse_result"

module Pars
  # Tools for creating commonly useful `Parser` instances.
  module Parse
    extend self

    # Provides a notation for building complex parsers that combine the result
    # of a number of component parsers.
    macro do(body)
      {% non_expression_types = {"Assign", "TypeNode", "Splat", "Union",
                                 "UninitializedVar", "TypeDeclaration",
                                 "Generic", "ClassDef", "Def",
                                 "VisibilityModifier", "MultiAssign"} %}
      {% if non_expression_types.includes? body.last.class_name %}
        {{body.last.raise "expected last operation in monad to be an expression, got a '#{body.last.class_name}'"}}
      {% end %}
      ({{body[0].args[0]}}).bind do |{{body[0].receiver}}|
      {% for i in 1...body.size - 1 %}
        {% if body[i].class_name == "Assign" %}
            {{body[i].target}} = {{body[i].value}}
        {% else %}
          {% if body[i].class_name == "Call" && body[i].name == "<=" %}
            ({{body[i].args[0]}}).bind do |{{body[i].receiver}}|
          {% elsif non_expressions_types.includes? body[i].class_name %}
            {{body[i].raise "expected operation '<=' or '=', got '#{body[i].name}'"}}
          {% else %}
            {{body[i]}}
          {% end %}
        {% end %}
      {% end %}
        {{body[body.size - 1]}}
      {% for i in 1...body.size - 1 %}
        {% if body[i].class_name == "Call" && body[i].name == "<=" %}
          end
        {% end %}
      {% end %}
      end
    end

    # Always succeeds with *value* and does not consume any input.
    def const(value : T) : Parser(T) forall T
      Parser(T).const value
    end

    # Parser that returns the parse head as a `Char`.
    def char : Parser(Char)
      Parser.char
    end

    # Parser that return the byte vaue at the parse head.
    def byte : Parser(UInt8)
      Parser.byte
    end

    # Parser that succeeds with *value* if *block* evaluates to true when passed
    # the value.
    #
    # In most cases this should not be used externally and is instead a tool for
    # composing parsers.
    def cond(value : T, expected : T | String? = nil, &block : T -> Bool) : Parser(T) forall T
      Parser(T).new do |context|
        if block.call value
          ParseResult(T).new value, context
        else
          message = case expected
                    when T
                      "expected '#{expected}', got '#{value}'"
                    when String
                      "expected #{expected}, got '#{value}'"
                    else
                      "unsatisfied predicate, got '#{value}'"
                    end
          ParseResult(T).error message, context
        end
      end
    end

    # Parser that return the context head if it satisfies *block*.
    #
    # *expected* can be optionally specified for providing a human friendly
    # ParseError on fail.
    def char_if(expected = nil, &block : Char -> Bool) : Parser(Char)
      Parser.char.bind do |value|
        cond value, expected, &block
      end
    end

    # :ditto:
    def byte_if(expected = nil, &block : UInt8 -> Bool) : Parser(UInt8)
      Parser.byte.bind do |value|
        cond value, expected, &block
      end
    end

    # Parser that tests equivalence to *value* at the parse head.
    #
    # If equivalent *value* itself is returned and the parse head progresses.
    def eq(value : T) : Parser(T) forall T
      Parser.head.bind do |head|
        cond value, value, &.===(head)
      end
    end

    # Parser that matches for a specific *char* at the parse head.
    def char(char : Char) : Parser(Char)
      char_if char, &.==(char)
    end

    # Parser that matches for a specific *byte* at the parse head.
    def byte(byte : UInt8) : Parser(UInt8)
      byte_if byte, &.==(byte)
    end

    # Creates a `Parser(String)` that looks at the current parse position and
    # expects the array of characters in the string `s` (`s.chars`) to be
    # consecutively present.
    def string(string : String) : Parser(String)
      case string.size
      when 0
        const string
      when 1
        char(string[0]) >> const string
      else
        string.each_char.map(&->char(Char)).reduce do |a, b|
          a >> b
        end >> const string
      end
    end

    # Creates a `Parser(Bytes)` that looks at the current parse position and
    # expects a series of bytes to be consecutively present.
    def bytes(bytes : Bytes) : Parser(Bytes)
      case bytes.size
      when 0
        const bytes
      when 1
        byte(bytes[0]) >> const bytes
      else
        bytes.each.map(&->byte(UInt8)).reduce do |a, b|
          a >> b
        end >> const bytes
      end
    end

    # Creates a `Parser(Char)` that looks at the current parse position and
    # expects the current character to be present in the string `s`.
    def one_char_of(string_or_list : String | Enumerable(Char)) : Parser(Char)
      char_if "a character from #{string_or_list}", &.in?(string_or_list)
    end

    # Functions identically to `Parse.one_char_of`, but reverses the expected
    # input. If the current character is present in `s`, then the parse fails.
    def no_char_of(string_or_list : String | Enumerable(Char)) : Parser(Char)
      char_if "no character in #{string_or_list}", &.in?(string_or_list).!
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
    def lowercase
      char_if "a lowercase character", &.lowercase?
    end

    # Parses a character of the uppercase alphabet.
    def uppercase
      char_if "an uppercase character", &.uppercase?
    end

    # Parses a character in the alphabet regardless of case.
    def letter
      char_if "a letter", &.letter?
    end

    def alphanumeric
      char_if "an alphanumeric character", &.alphanumeric?
    end

    # Parses a full word of at least one character.
    def word
      (alphanumeric * (1..)).map &.join
    end

    def whitespace
      char_if "a whitespace character", &.whitespace?
    end

    # Parses a digit as a character.
    def digit
      char_if "a digit", &.number?
    end

    # Parses an integer as a String.
    def integer
      (digit * (1..)).map &.join
    end

    # Parses a fractional number as a String.
    def decimal
      (integer + (char '.') + integer).map &.join
    end

    # Parses a number as a String.
    def number
      decimal | integer
    end
  end
end
