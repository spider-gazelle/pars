require "spec"
require "../../src/pars"

include Pars

describe Pars::Parse do
  describe ".const" do
    p = Parse.const 'a'
    it "returns a constant value for every input" do
      p.parse("abc").should eq 'a'
      p.parse("123").should eq 'a'
      p.parse("").should eq 'a'
    end
  end

  describe "do macro" do
    it "supports sequencing multiple parsers" do
      p = Parse.do({
        alpha <= Parse.letter,
        digit <= Parse.digit,
        Parse.const({alpha, digit})
      })
      p.parse("a1").should eq({'a', '1'})
      p.parse("42").should be_a ParseError
    end
  end

  describe ".cond" do
    it "success when the predicate is true" do
      p = Parse.cond 'a' { true }
      p.parse("").should eq 'a'
    end
    it "produces a ParseError when the prediciate is false" do
      p = Parse.cond 'a' { false }
      p.parse("").should be_a ParseError
    end
  end

  describe ".eq" do
    p = Parse.eq 'a'.ord
    it "checks equivalence at the parse position" do
      p.parse("abc").should eq 'a'.ord
      p.parse("bca").should be_a ParseError
      p.parse("cab").should be_a ParseError
    end
  end

  describe ".char" do
    p = Parse.char 'a'
    it "matches against a char at the current parse position" do
      p.parse("abc").should eq 'a'
      p.parse("bca").should be_a ParseError
      p.parse("cab").should be_a ParseError
    end
  end

  describe ".byte" do
    p = Parse.byte 0x0
    it "matches for a byte value" do
      p.parse(Bytes[0x0]).should eq 0x0
      p.parse("foo").should be_a ParseError
    end
  end

  describe ".string" do
    p = Parse.string "cat"
    it "matches against the a string" do
      p.parse("cat").should eq "cat"
      p.parse("dog").should be_a ParseError
      p.parse("").should be_a ParseError
    end
  end

  describe ".bytes" do
    p = Parse.bytes Bytes[0xDE, 0xAD, 0xBE, 0xEF]
    it "matches against byte values" do
      p.parse(Bytes[0xDE, 0xAD, 0xBE, 0xEF]).should eq Bytes[0xDE, 0xAD, 0xBE, 0xEF]
      p.parse(Bytes[0xDE, 0xAD]).should be_a ParseError
      p.parse(Bytes[0x0]).should be_a ParseError
      p.parse("foo").should be_a ParseError
    end
  end

  describe ".one_char_of" do
    p = Parse.one_char_of "abc"
    it "matches any character from the passed string" do
      p.parse("apple").should eq 'a'
      p.parse("banana").should eq 'b'
      p.parse("carrot").should eq 'c'
      p.parse("dragonfruit").should be_a ParseError
    end
  end

  describe ".no_char_of" do
    p = Parse.no_char_of "abc"
    it "fails for any character in the passed string" do
      p.parse("apple").should be_a ParseError
      p.parse("banana").should be_a ParseError
      p.parse("carrot").should be_a ParseError
      p.parse("dragonfruit").should eq 'd'
    end
  end

  describe ".non_empty_list" do
    space = Parse.whitespace * (0..)
    comma = space >> Parse.char(',') << space
    word = Parse.word
    p = Parse.non_empty_list word, comma
    it "builds an array from the wrapped element and delimiter parsers" do
      p.parse("").should be_a ParseError
      p.parse("test").should eq ["test"]
      p.parse("hello, world").should eq ["hello", "world"]
      p.parse("par , s3k").should eq ["par", "s3k"]
    end
  end
end
