require "./parser"
require "./parse_result"

module Pars3k
  module Parse
    extend self

    # Creates a `Parser(T)` that always succeeds with `value`.
    def constant(value : T) : Parser(T) forall T
      Parser(T).new do |context|
        ParseResult(T).new value, context
      end
    end

    # Creates a `Parser(Char)` that looks at the current parse position and
    # expects `c`.
    def char(char : Char)
      Parser(Char).new do |context|
        if context.exhausted?
          ParseResult(Char).error "expected '#{char}', input ended", context
        elsif context.peek == char
          ParseResult(Char).new char, context.next
        else
          ParseResult(Char).error "expected '#{char}', got '#{context.peek}'", context
        end
      end
    end

    # Creates a `Parser(String)` that looks at the current parse position
    # expects the array of characters in the string `s` (`s.chars`) to be
    # consecutively present.
    def string(string : String) : Parser(String)
      if string.size == 0
        constant ""
      elsif string.size == 1
        (char string[0]).transform &.to_s
      else
        parser = char string[0]
        string[1...string.size].chars.each do |char|
          parser += char char
        end
        parser.transform { |_| string }
      end
    end

    # Creates a `Parser(Char)` that looks at the current parse position and
    # expects the current character to be present in the string `s`.
    def one_char_of(string : String) : Parser(Char)
      parser = char string[0]
      (1...string.size).each do |index|
        parser |= char string[index]
      end
      parser
    end

    # Functions identically to `Parse.one_char_of`, but reverses the expected
    # input. If the current character is present in `s`, then the parse fails.
    def no_char_of(string : String) : Parser(Char)
      Parser(Char).new do |context|
        if context.exhausted?
          ParseResult(Char).error "expected none of '#{string}', input ended", context
        elsif string.includes? context.peek
          ParseResult(Char).error "expected none of '#{string}', got #{context.peek}", context
        else
          ParseResult(Char).new context.peek, context.next
        end
      end
    end

    # Creates a `Parser(Array(T))` that continuously parses the parser `p` until
    # it fails. It succeeds with an array of the successive values.
    def many_of(parser : Parser(T)) : Parser(Array(T)) forall T
      Parser(Array(T)).new do |ctx|
        result = parser.run ctx
        results = [] of T
        context = ctx
        count = 1
        while !result.errored
          context = result.context
          results << result.value!
          result = parser.run context
          count += 1
        end
        ParseResult(Array(T)).new results, context
      end
    end

    # Creates a `Parser(Array(T))` that works like `Parse.many_of`, but expects
    # at least one parse to succeed. Returns with the error of the first failure
    # if it does not succeed.
    def one_or_more_of(parser : Parser(T)) : Parser(Array(T)) forall T
      Parser(Array(T)).new do |context|
        result = parser.run context
        if result.errored
          ParseResult(Array(T)).error result.error!
        else
          chars = [result.value!]
          new_parser = many_of parser
          new_result = new_parser.run result.context
          new_result.value!.each do |char|
            chars << char
          end
          ParseResult(Array(T)).new chars, new_result.context
        end
      end
    end

    # Creates a `Parser(Array(T))` that works like `Parse.many_of`, but fails if
    # the number of successful parses is below the lower bound of the range `r`,
    # and stops parsing if the number of successful parses goes over the limit.
    def some_of(parser : Parser(T), range : Range) : Parser(Array(T)) forall T
      Parser(Array(T)).new do |ctx|
        result = parser.run ctx
        if result.errored && !range.includes? 0
          next ParseResult(Array(T)).error result.error!
        end

        results = [] of T
        max = range.end - (range.excludes_end? ? 1 : 0)
        while !result.errored
          results << result.value!
          break if results.size >= max
          result = parser.run result.context
        end

        unless range.includes? results.size
          next ParseResult(Array(T)).error "expected #{range} parses, got #{results.size} parses", result.context
        end

        ParseResult(Array(T)).new results, result.context
      end
    end

    # Runs `Parse.some_of(p, count..count)`.
    def some_of(parser : Parser(T), count : Int32) : Parser(Array(T)) forall T
      some_of(parser, count..count)
    end

    # `Parse.one_of(p : Parser(T))` is a shortcut to `Parse.some_of(p, 0..1)`.
    def one_of(parser : Parser(T)) : Parser(Array(T)) forall T
      some_of parser, ..1
    end

    # Creates a `Parser(T | Nil)` that will return nil if no parse is found.
    # Otherwise, it returns the value of `T`. To use the result effectively,
    # check the return type with `result.nil?`.
    def one_of?(parser : Parser(T)) : Parser(T?) forall T
      Parser(T?).new do |context|
        result = parser.run context
        if result.errored
          ParseResult(T?).new(nil, result.context)
        else
          ParseResult(T?).new(result.value!, result.context)
        end
      end
    end

    # Reates a `Parser(T | Nil)` that will always return nil if the initial
    # `value` is nil. This is to be used with `do_parse` or `Parser#sequence`.
    # It can be used to ignore parsers if one before it yielded a nil value.
    def if_not_nil?(parser : Parser(T), value : B) : Parser(T?) forall T, B
      if value.nil?
        Parser(T?).new { |context| ParseResult(T?).new(nil, context) }
      else
        Parser(T?).new do |context|
          result = parser.run context
          if result.errored
            ParseResult(T?).error result.error!
          else
            ParseResult(T?).new result.value!, result.context
          end
        end
      end
    end

    # Creates a `Parser(Array(T))` that will continue to parse with *parser*
    # delimited by *delimter* until an error with either occurs.
    def delimited_list(parser : Parser(A), delimiter : Parser(B)) : Parser(Array(A)) forall A, B
      Parser(Array(A)).new do |ctx|
        result = parser.run ctx
        if result.errored
          next ParseResult(Array(A)).error result.error!
        end
        results = [result.value!] of A
        context = ctx
        count = 1
        delimiter_result = delimiter.run result.context
        while !delimiter_result.errored
          result = parser.run delimiter_result.context
          if result.errored
            break
          end
          context = result.context
          results << result.value!
          delimiter_result = delimiter.run context
        end
        ParseResult(Array(A)).new results, delimiter_result.context
      end
    end

    # Transforms *parser* by adding all of the characters of a result into a
    # string.
    def join(parser : Parser(Array(Char))) : Parser(String)
      parser.transform &.reduce "" { |v, c| v + c }
    end

    # Parses a character of the lowercase alphabet.
    def alphabet_lower
      one_char_of "abcdefghijklmnopqrstuvwxyz"
    end

    # Parses a character of the uppercase alphabet.
    def alphabet_upper
      one_char_of "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    end

    # Parses a character in the alphabet regardless of case.
    def alphabet
      alphabet_lower | alphabet_upper
    end

    # Parses a full word of at least one character.
    def word
      (one_or_more_of alphabet).transform &.join
    end

    # Parses a digit as a character.
    def digit
      one_char_of "0123456789"
    end

    # Parses an integer as an actual `Int`.
    def int
      (one_or_more_of digit).transform &.join
    end

    # Parses a float as an actual `Float`.
    def float
      do_parse({
        whole <= (join one_or_more_of digit),
        _ <= (one_of? char '.'),
        decimal <= (join many_of digit),
        constant "#{whole}#{decimal.size == 0 ? ".0" : "." + decimal}".to_f,
      })
    end
  end
end
