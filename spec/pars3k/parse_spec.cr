require "spec"
require "../../src/pars3k"

include Pars3k

describe Pars3k::Parse do
  describe "parsers" do
    describe ".constant" do
      p = Parse.constant 'a'
      it "returns a constant value for every input" do
        p.parse("abc").should eq 'a'
        p.parse("123").should eq 'a'
        p.parse("").should eq 'a'
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

    describe ".string" do
      p = Parse.string "cat"
      it "matches against the a string" do
        p.parse("cat").should eq "cat"
        p.parse("dog").should be_a ParseError
        p.parse("").should be_a ParseError
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
  end

  describe "combinators" do
    a = Parse.char 'a'

    describe ".many_of" do
      p = Parse.many_of a
      it "matches the wrapped parser zero or more times" do
        p.parse("abc").should eq ['a']
        p.parse("aabbcc").should eq ['a', 'a']
        p.parse("aaaaaah").should eq ['a', 'a', 'a', 'a', 'a', 'a']
        p.parse("pars3k").should eq [] of Char
      end
    end

    describe ".one_or_more_of" do
      p = Parse.one_or_more_of Parse.one_char_of "act"
      it "matches the wrapped parser at least once" do
        p.parse("cat").should eq ['c', 'a', 't']
        p.parse("act").should eq ['a', 'c', 't']
        p.parse("t").should eq ['t']
        p.parse("nope").should be_a ParseError
      end
    end

    describe ".some_of" do
      p = Parse.some_of a, 2..4
      it "matches the wrapped parser within the range bounds" do
        p.parse("").should be_a ParseError
        p.parse("a").should be_a ParseError
        p.parse("aa").should eq ['a', 'a']
        p.parse("aaa").should eq ['a', 'a', 'a']
        p.parse("aaaa").should eq ['a', 'a', 'a', 'a']
        p.parse("aaaaa").should eq ['a', 'a', 'a', 'a']
      end
    end

    describe ".one_of" do
      p = Parse.one_of a
      it "matches zero or one times" do
        p.parse("").should eq [] of Char
        p.parse("a").should eq ['a']
        p.parse("aa").should eq ['a']
      end
    end

    describe ".one_of?" do
      p = Parse.one_of? a
      it "matches once, or returns nil" do
        p.parse("").should be_nil
        p.parse("a").should eq 'a'
        p.parse("aa").should eq 'a'
      end
    end

    describe ".if_not_nil?" do
      b = Parse.char 'b'
      p = Parse.one_of?(a).sequence do |a_result|
        Parse.if_not_nil?(b, a_result).sequence do |b_result|
          Parse.constant({a_result, b_result})
        end
      end
      it "continues parsing when passed non-nil values" do
        p.parse("ab").should eq({'a', 'b'})
        p.parse("ac").should be_a ParseError
        p.parse("b").should eq({nil, nil})
      end
    end

    describe ".delimited_list" do
      space = Parse.many_of Parse.char ' '
      comma = space >> Parse.char(',') >> space
      word = Parse.join Parse.one_or_more_of Parse.one_char_of "abcdefghijklmnopqrstuvwxyz01234567890"
      p = Parse.delimited_list word, comma
      it "builds an array from the wrapped element and delimiter parsers" do
        p.parse("").should be_a ParseError
        p.parse("test").should eq ["test"]
        p.parse("hello, world").should eq ["hello", "world"]
        p.parse("par , s3k").should eq ["par", "s3k"]
      end
    end
  end

  describe "transforms" do
    describe ".join" do
      alpha = Parse.one_char_of "abcdefghijklmnopqrstuvwxyz"
      word = Parse.many_of alpha
      word_joined = Parse.join word
      it "combines characters from parser output into a string" do
        word.parse("hello").should eq ['h', 'e', 'l', 'l', 'o']
        word_joined.parse("hello").should eq "hello"
      end
    end
  end
end
