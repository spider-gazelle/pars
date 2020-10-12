require "spec"
require "../../src/pars"

include Pars

describe Parser do
  a = Parse.char 'a'
  b = Parse.char 'b'
  c = Parse.char 'c'

  describe ".const" do
    p = Parser.const 42
    it "always returns the same value regardless of input" do
      p.parse("a").should eq 42
      p.parse("test").should eq 42
      p.parse("").should eq 42
      p.parse(Bytes[0xB, 0xE, 0xE, 0xF]).should eq 42
      p.parse(Bytes.empty).should eq 42
    end
    it "does not consume any of the input" do
      ctx = ParseContext.new "hello"
      ctx.pos.should eq 0
      res = p.run ctx
      res.value.should eq 42
      res.context.should eq ctx
      res.context.pos.should eq 0
    end
  end

  describe ".fail" do
    p = Parser(Char).fail "nope"
    it "fails for every input" do
      p.parse("a").should be_a ParseError
      p.parse("test").should be_a ParseError
      p.parse("").should be_a ParseError
      p.parse(Bytes[0xB, 0xE, 0xE, 0xF]).should be_a ParseError
      p.parse(Bytes.empty).should be_a ParseError
    end
    it "does not consume any of the input" do
      ctx = ParseContext.new "hello"
      ctx.pos.should eq 0
      res = p.run ctx
      res.value.should be_a ParseError
      res.context.should eq ctx
      res.context.pos.should eq 0
    end
  end

  describe ".head" do
    p = Parser.head
    it "returns the parse head" do
      p.parse("a").should eq 'a'
      p.parse("b").should eq 'b'
    end
    it "progresses the parse context" do
      ctx = ParseContext.new "ab"
      res = p.run ctx
      res.context.pos.should eq 1
    end
    it "provides a parse error when the end of input is reached" do
      p.parse("").should be_a ParseError
    end
  end

  describe "#map" do
    it "applies the transform to the parser output" do
      p = a.map &.to_s
      p.parse("a").should eq "a"
    end
    it "captures exception in the transform as a ParseError" do
      p = a.map { |_| raise Exception.new "oh no" }
      result = p.parse("a")
      result.should be_a ParseError
      result.message.should be "oh no"
    end
  end

  describe "#+" do
    it "sequences `self` with another parser" do
      p = a + b
      p.parse("a").should be_a ParseError
      p.parse("ab").should eq({'a', 'b'})
      p.parse("abc").should eq({'a', 'b'})
    end
    it "flattens the results when chaining" do
      p = a + b + c
      p.parse("abc").should eq({'a', 'b', 'c'})
    end
    it "returns a ParseError if any fail" do
      p = a + b + c
      p.parse("zbc").should be_a ParseError
      p.parse("azc").should be_a ParseError
      p.parse("abz").should be_a ParseError
    end
  end

  describe "#<<" do
    p = a << b
    it "returns the result of self if both parsers succeed" do
      p.parse("ab").should eq 'a'
    end
    it "returns a ParseError if self errors" do
      p.parse("bb").should be_a ParseError
    end
    it "preserves the previous context when self fails" do
      ctx = ParseContext.new "bb"
      res = p.run ctx
      res.value.should be_a ParseError
      res.context.pos.should eq 0
    end
    it "preserves the parse context when other fails" do
      ctx = ParseContext.new "aa"
      res = p.run ctx
      res.value.should be_a ParseError
      res.context.pos.should eq 0
    end
  end

  describe "#>>" do
    p = a >> b
    it "returns the result of other if both parsers succeed" do
      p.parse("ab").should eq 'b'
    end
    it "returns a parse error if other fails" do
      p.parse("aa").should be_a ParseError
    end
    it "preserves the previous context when self fails" do
      ctx = ParseContext.new "bb"
      res = p.run ctx
      res.value.should be_a ParseError
      res.context.pos.should eq 0
    end
    it "preserves the parse context when other fails" do
      ctx = ParseContext.new "aa"
      res = p.run ctx
      res.value.should be_a ParseError
      res.context.pos.should eq 0
    end
  end

  describe "#|" do
    p = a | b
    it "returns the result if either parser succeeds" do
      p.parse("a").should eq 'a'
      p.parse("b").should eq 'b'
    end
    it "returns a ParseError if both fail" do
      p.parse("c").should be_a ParseError
    end
    it "allows chaining with a custom error message" do
      result = (p | "nope").parse "c"
      result.should be_a ParseError
      result.as(ParseError).message.should eq "nope"
    end
    it "builds a union type from component parsers" do
      composite = p | (Parse.string "foo") | Parse.byte(0x0).map(&->Box.new(UInt8)) | p
      typeof(composite).should eq Parser(Char | String | Box(UInt8))
      typeof(composite.parse("foo")).should eq (Char | String | Box(UInt8) | ParseError)
    end
  end

  describe "#&" do
    it "succeeds when both succeed" do
      p = a & Parse.letter
      p.parse("a").should eq 'a'
    end
    it "returns a ParseError if either fail" do
      (a & b).parse("a").should be_a ParseError
      (b & a).parse("a").should be_a ParseError
    end
  end

  describe "#^" do
    it "succeeds if a succeeds" do
      (a ^ b).parse("a").should eq 'a'
    end
    it "succeeds if b succeeds" do
      (a ^ b).parse("b").should eq 'b'
    end
    it "fails if both fail" do
      (a ^ b).parse("c").should be_a ParseError
    end
    it "fails if both succeed" do
      (a ^ a).parse("a").should be_a ParseError
    end
    it "provides a union type as the result" do
      str = Parse.string "foo"
      (a ^ str).parse("a").should be_a Char | String
    end
  end

  describe "#*(Int)" do
    it "repeats the parser the specified number of times" do
      (a * 1).parse("aaa").should eq ['a']
      (a * 2).parse("aaa").should eq ['a', 'a']
      (a * 3).parse("aaa").should eq ['a', 'a', 'a']
    end
    it "returns an empty array for 0" do
      (a * 0).parse("aaa").should eq [] of Char
    end
    it "fails if the count isn't met" do
      (a * 3).parse("a").should be_a ParseError
    end
  end

  describe "#*(Range)" do
    p = a * (1..2)
    it "stops matching after range.end" do
      p.parse("aab").should eq ['a', 'a']
    end
    it "succeeds if the number of matches is within the range" do
      p.parse("ab").should eq ['a']
    end
    it "failes if the range.start is not met" do
      p.parse("b").should be_a ParseError
    end
    it "succeeds on a endless range if range.start is met" do
      (a * (0..)).parse("").should eq [] of Char
      (a * (1..)).parse("a").should eq ['a']
      (a * (0..)).parse("aab").should eq ['a', 'a']
    end
  end
end
