require "spec"
require "../../src/pars3k"

include Pars3k

describe Pars3k::Parser do
  a = Parse.char 'a'
  b = Parse.char 'b'

  describe "#transform" do
    it "applies the transoform to the parser output" do
      p = a.transform &.to_s
      p.parse("a").should eq "a"
    end
    it "captures exception in the transform as a ParseError" do
      p = a.transform { |_| raise Exception.new "oh no" }
      result = p.parse("a")
      result.should be_a ParseError
      result.message.should be "oh no"
    end
  end

  describe "#+" do
    p = a + b
    it "sequences `self` with another parser" do
      p.parse("a").should be_a ParseError
      p.parse("ab").should eq 'b'
    end
  end

  describe "#<<" do
    p = a << b
    it "returns the result of self if both parsers succeed" do
      p.parse("ab").should eq 'a'
    end
    it "returns a ParseError is self errors" do
      p.parse("bb").should be_a ParseError
    end
    it "returns a ParseError is other errors" do
      p.parse("aa").should be_a ParseError
    end
  end

  describe "#>>" do
    p = a >> b
    it "returns the result of other if both parsers succeed" do
      p.parse("ab").should eq 'b'
    end
    it "returns a ParseError is self errors" do
      p.parse("bb").should be_a ParseError
    end
    it "returns a ParseError is other errors" do
      p.parse("aa").should be_a ParseError
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
  end
end
