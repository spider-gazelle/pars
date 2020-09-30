require "spec"
require "../src/pars3k"

include Pars3k

describe Pars3k::Parse do
  describe "parsers" do
    describe ".constant" do
      p = Parse.constant 'a'
      it "returns a constant value for every input" do
        p.parse("abc").should eq('a')
        p.parse("123").should eq('a')
        p.parse("").should eq('a')
      end
    end

    describe ".char" do
      p = Parse.char 'a'
      it "matches against a char at the current parse position" do
        p.parse("abc").should eq('a')
        p.parse("bca").should be_a(ParseError)
        p.parse("cab").should be_a(ParseError)
      end
    end

    describe ".string" do
      p = Parse.string "cat"
      it "matches against the a string" do
        p.parse("cat").should eq("cat")
        p.parse("dog").should be_a(ParseError)
        p.parse("").should be_a(ParseError)
      end
    end

    describe ".one_char_of" do
      p = Parse.one_char_of "abc"
      it "matches any character from the passed string" do
        p.parse("apple").should eq('a')
        p.parse("banana").should eq('b')
        p.parse("carrot").should eq('c')
        p.parse("dragonfruit").should be_a(ParseError)
      end
    end

    describe ".no_char_of" do
      p = Parse.no_char_of "abc"
      it "failes for any character in the passed string" do
        p.parse("apple").should be_a(ParseError)
        p.parse("banana").should be_a(ParseError)
        p.parse("carrot").should be_a(ParseError)
        p.parse("dragonfruit").should eq('d')
      end
    end
  end

  describe "combinators" do
  end
end
