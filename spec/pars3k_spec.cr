require "spec"
require "../src/pars3k"

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
    describe ".many_of" do
      p = Parse.many_of Parse.char 'a'
      it "continues to parse as long as the wrapped parser succeeds" do
        p.parse("abc").should eq ['a']
        p.parse("aabbcc").should eq ['a', 'a']
        p.parse("aaaaaah").should eq ['a', 'a', 'a', 'a', 'a', 'a']
        p.parse("pars3k").should eq [] of Char
      end
    end

    describe ".one_or_more_of" do
      p = Parse.one_or_more_of Parse.one_char_of "act"
      it "matches the wrapped parser one or more time" do
        p.parse("cat").should eq ['c', 'a', 't']
        p.parse("act").should eq ['a', 'c', 't']
        p.parse("t").should eq ['t']
        p.parse("nope").should be_a ParseError
      end
    end

    describe ".some_of" do

    end

    describe ".one_of" do

    end

    describe ".one_of?" do

    end

    describe ".if_not_nil?" do

    end

    describe ".delimited_list" do

    end
  end

  describe "transforms" do
    describe ".join" do

    end
  end

  describe "prebaked" do
    describe ".alphabet_lower" do

    end

    describe ".alphabet_upper" do

    end

    describe ".alphabet" do

    end

    describe ".word" do

    end

    describe ".digit" do

    end

    describe ".int" do

    end

    describe ".float" do

    end
  end
end
