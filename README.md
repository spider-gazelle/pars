# Pars

`Pars` is a library for building monadic parser combinators in crystal-lang.
It works with minimal object allocation to extract domain-specific representation from String or Bytes input.

A combinator parser is a system that allows for the creation of small parsers which can then compose to represent more complex semantics.
This process then repeats, allowing for increasingly complexity.
Small parsers combine with logic (like OR, AND, etc.) and sequencing to create larger, more meaningful parsers.
Ultimately providing a single parser that models a full domain grammar.

This style of parser allows for creating interpreted programming languages, decoding markup, reading files of different formats, decoding communication protocols and other uses where there is a need to extract information from String or Bytes data based on defined syntax.

For a more in-depth introduction, see [Monadic Parser Combinators](https://www.cs.nott.ac.uk/~pszgmh/monparsing.pdf).


## Usage

```crystal
require "pars"
include Pars
```

While not required, including `Pars` is _highly recommended_ for ease of access.

### Primitive parsers

```crystal
char_a = Parse.char 'a'

puts char_a.parse "abc" #=> a
```

This example creates a `Parser(Char)` from `Parse.char`, and parses the string `"abc"` on it.
The character parser looks at the beginning of the string, and looks for the first character.
If the first character matches the character supplied, then the parse will succeed and the parse result will return the character that matched.

```crystal
puts char_a.parse "bca" #=> expected 'a', got 'b'
```

This example uses the same `char_a` parser, but parses string `"bca"` on it.
Because it doesn't start with `'a'`, the parse fails and returns a `ParseError`.
A `ParseError` contains a message about the parse failure, available via `ParseError#message`.
As such, `Parser(T)#parse` returns a union of `(T | ParseError)`, as it can return either.

```crystal
str_cat = Parse.string "cat"

puts str_cat.parse "cat" #=> cat
puts str_cat.parse "cats are cool" #=> cat
puts str_cat.parse "dog" #=> expected 'cat', got 'd'
```

This example creates a new primitive parser, the `Parser(String)` created by `Parse.string(String)`.
It expects an exact copy of the string provided; in this example the text `"cat"`.

When constructing parsers for non-string based input, `Parser.byte` is also provided.
```crystal
null_byte = Parse.byte 0x0

puts null_byte.parse Bytes[0xDE, 0xAD, 0xBE, 0xEF] #=> expected `0`, got '222'
```

Similarly `Parser.bytes` is available for matching a specific byte sequence.
```crystal
bovine = Parse.bytes Bytes[0xBE, 0xEF]

puts bovine.parse Bytes[0xBE, 0xEF] #=> Bytes[0xBE, 0xEF]
```

### Conditional parsers

In some cases, you may want to retrieve a value from the input that matches certain criteria.
Two base conditional parsers provide this:

```crystal
space = Parse.char_if &.whitespace?
```

or for binary inputs

```crystal
low_val = Parse.byte_if { |b| b <= 10 }
```


### Amalgam parsers

```crystal
char_a = Parse.char 'a'
char_b = Parse.char 'b'
parse_ab = char_a | char_b

puts parse_ab.parse "abc" #=> a
puts parse_ab.parse "bca" #=> b
puts parse_ab.parse "cab" #=> expected 'b', got 'c'
```

This example creates three parsers:
- a `Parser(Char)` that expects a character of `'a'`,
- a `Parser(Char)` that expects a character of `'b'`, and
- a `Parser(Char)` created using the `|` operator that will try the left parser first, then the right, and use the successful parser.

The `|` operator allows you to create amalgam parsers by using OR logic.
It first tries the parser on the left, then the right.
If both fail, it will throw the `ParseError` given by the rightmost parser.

This process is tedious for large masses of characters, such as if you wanted to accept all letters of the alphabet.
For this sake, there exists `Parse.one_char_of`, which looks for any character in the provided string of list.

```crystal
parse_alphabet = Parse.one_char_of "abcdefghijklmnopqrstuvwxyz"

puts parse_alphabet.parse "abc" #=> a
puts parse_alphabet.parse "bca" #=> b
puts parse_alphabet.parse "xyz" #=> x
puts parse_alphabet.parse "yzx" #=> y
puts parse_alphabet.parse "123" #=> expected 'z', got '1'
```

This example creates a parser that accepts a char from the provided list.
As seen, alphabetical characters parse, but numerical characters do not, as they were not in the original string of the alphabet.

Prebuilt parsers exist for common character types: `Parse.lowercase`, `Parse.uppercase`, `Parse.letter`, `Parse.digit`, `Parse.alphanumeric`, `Parse.whitespace`.

#### Repetitive parsers

To create a parser that repeats, use the `*` operator.
This is available on any `Parser(T)`, and outputs a `Parser(Array(T))`.

When used with an integer, this creates a parser that matches an exact number of times.

```crystal
triple_a = Parse.char('a') * 3

triple_a.parse("aaa") #=> ['a', 'a', 'a']
triple_a.parse("aa") #=> expected 'a', input ended
```

To match a variable number of times, use a `Range`.

```crystal
some_a = Parse.char('a') * (1..3)

some_a.parse("aaa") #=> ['a', 'a', 'a']
some_a.parse("aa") #=> ['a', 'a']
```

Endless ranges are also supported, which will continue to match until a ParseError occurs.

```crystal
existential_dread = Parse.char('a') * (5..)

existential_dread.parse("aaa") #=> expected 'a', input ended
existential_dread.parse("aaaaaaaaaa") #=> ['a', 'a', 'a', 'a', 'a', 'a', 'a', 'a', 'a', 'a']
```

```crystal
word = Parse.letter * (1..)

puts word.parse "hello world" #=> ['h', 'e', 'l', 'l', 'o']
puts word.parse "abc" #=> ['a', 'b', 'c']
puts word.parse "123" #=> []
```

A clear issue exists with the above example: it returns a list of the characters.
If we want to convert this into a usable `String`, we have to transform the parser.

### Transforming parsers

Existing parsers can be "transformed" to create new parsers with new logic.
This provide the ability to move from primitive types to domain-specific types.
To transform a parser, use the `Parser(T)#map(T -> B)` method.
This accepts a block that receives the resulting value of a parse as a parameter, and outputs a transformed/mapped value.

For example, if you created a parser that accepted numbers:

```crystal
digit = Parse.one_char_of "0123456789"
```

Upon parsing it, it would yield characters on success:

```crystal
puts (digit.parse "1").class #=> Char
```

we find that the result is a `Char`, not any form of a `Number`! To solve this, we can transform the parser:

```crystal
digit = (Parse.one_char_of "0123456789").map &.to_i

puts digit.parse "1" #=> 1
puts (digit.parse "1").class #=> Int32
```

Success! Now the parsed value from our parser is the correct type, `Int32`.

Back to the issue we found in the word parser from the previous section, we can transform the `Array(Char)` to
a `String`.

```crystal
word = (Parse.letter * (1..)).map &.join

puts word.parse "hello world" #=> hello
puts word.parse "abc" #=> abc
puts word.parse "" #=>
```

This identical `word` parser is available as `Parse.word` (`Parser(String)`).

### Logical combinations

The `|` (OR) operator already discussed as accompanied by other logical operators.

- `A & B` (AND) creates a new parser that ensure both A and B successfull parse for the same input and returns the results of B.
- `A ^ B` (XOR) creates a new parser that succeeds with the result of A or B, but fails if both succeed.

### Sequencing parsers

- `A >> B` creates a new parser that ensures both A and B parse sequentially, but results with the value of B.
- `A << B` creates a new parser that ensures both A and B parse sequentially, but results with the value of A.
- `A + B` creates a new parser that ensure both A and B parse sequentially, returning the results as a Tuple.

```crystal
letter = Parse.letter
digit = Parse.digit
parser_take_digit = letter >> digit
parser_take_letter = letter << digit

puts parser_take_digit.parse "a1" #=> 1
puts parser_take_digit.parse "b2" #=> 2

puts parser_take_letter.parse "a1" #=> a
puts parser_take_letter.parse "b2" #=> b
```

In this example, two parsers are created, `letter` and `digit`.
Then, two new parsers are created using the `>>` and `<<` operators.
The first parses both sequentially but results with the result of `digit`, and the second does the same but results with the value of `letter`.
Upon parsing these, the two parsers must work sequentially, but returns with the parser's result the operator is pointing toward.

### Parsing lists

`Parse` has a special parser that can parse a list of parsable items by parser `A`, delimited by parser `B`.
Using this, we can create a parser that parses through a list of words (using `Parser.word`), delimited by a second parser that looks for commas.

```crystal
word = Parser.word
optional_whitespace = Parser.whitespace * (0..)
comma = (Parser.char ',') << optional_whitespace

list_parser = Parse.list word, comma

puts list_parser.parse "hello, world" #=> ["hello", "world"]
puts list_parser.parse "how,are,    you" #=> ["how", "are", "you"]
puts list_parser.parse "123, 456" #=> []
puts list_parser.parse "hello world, how are you" #=> ["hello"]
```

### Complex sequential parsers

In the event you need to create complex sequential parsers, you can use `Parser(T)#bind`.
The `bind` method takes a block that receives the output of `Parser(T)` as a value, and must return
a new `Parser` of any type, or `Parser(B)`.
We can recreate the `parser_take_digit` and `parser_take_letter` parsers using this functionality:

```crystal
letter = Parse.letter
digit = Parse.digit

parser_take_digit = letter.bind do |char_result|
  digit.bind do |digit_result|
    Parse.const digit_result
  end
end
```

The original two parsers chain their execution, and ultimately a `Parse.const` parser returns.
`Parse.const` is a parser that takes in any value of type `T`.
When parsed, it _always_ returns the value of type `T`.
In this case, we create it with the `Char` result from `digit`.

```crystal
parser_letter_digit = letter.bind do |char_result|
  digit.bind do |digit_result|
    Parse.const({char_result, digit_result}) # a constant parser with a `Tuple(Char, Char)`
  end
end
```

This parser will parse strings like `a1`, `b2`, `c3`, etc., but return both of the retrieved values as a `Tuple`.

```crystal
result = parser_letter_digit.parse "a1"

puts result[0] #=> a
puts result[1] #=> 1
```

This form of parser sequencing can become tedious.
As a result, the library has a special macro inspired by Haskell's `do` statement.
It allows you to chain parsers like above, but in a much more linear and organized manner.
Here is the most recent sequential parser `parser_letter_digit` using `Parse.do`:

```crystal
parser_letter_digit = Parse.do({
  char_result <= letter,
  digit_result <= digit,
  Parse.const({char_result, digit_result})
})
```

The body of the `Parse.do` macro is a list of actions separated by commas.
The last element of this list _must_ be an expression that is ultimately returned through the new parser.

For each of the other elements in the list, they must be either parser results or local variables.

- Parser results look like `result_variable_name <= parser,`. In this case, the result from `parser` is
  stored as `result_variable_name`.
- Local variables are `variable_name = value,`. In this case, `variable_name` is set to `value`.

Utilizing these tools, more complex parsers are expressible.

```crystal
word = Parse.word

optional_whitespace = Parse.whitespace * (0..)
equals = optional_whitespace >> (Parse.char '=') << optional_whitespace

key_value_pair = Parse.do({
  key <= word,
  _ <= equals,
  value <= word,
  Parse.const({key, value})
})

comma = (Parse.char ',') << optional_whitespace

key_value_list = Parse.list key_value_pair, comma

puts key_value_list.parse "hello = world" #=> [{"hello", "world"}]
puts key_value_list.parse "how = are, you= sir" #=> [{"how", "are"}, {"you", "sir"}]
puts key_value_list.parse "all=     sorts,of   =supported, white = spaces" #=> [{"all", "sorts"}, {"of", "supported"}, {"white", "spaces"}]
```

### Custom parsers

Custom parsers can wrap arbitrary logic.
This is sometimes necessary if existing primitive parsers cannot combine effectively or efficiently.

```crystal
def char_parser(char)
  Parser(Char).new do |context|
    if context.exhausted?
      ParseResult(Char).error "expected '#{char}', got end of input", context
    elsif context.head === char
      ParseResult(Char).new char, context.next
    else
      ParseResult(Char).error "expected '#{char}', got '#{context.head}", context
    end
  end
end
```

This defines `char_parser(Char)`, which creates a parser that expects a character as specified.
This implementation is the same as the internal implementation `Parse.char(Char)`.
See the source code for more applications of Parsers derived from blocks.

## Docs

Generate docs with `crystal docs`.

## Acknowledgements

`Pars` is a fork of [Pars3k](https://github.com/voximity/pars3k).
It shares much of the same internals and structure but is _not_ API compatible.
The public API uses features, idioms and operators specific to crystal-lang.
While it may look and feel different, a significant hat-tip needs to go to the original work by [Voximity](https://github.com/voximity) and the authors of libraries which inspired it.
