require 'spec_helper'

describe RateBeer::Style do
  before :all do
    @valid   = RateBeer::Style.new(80)
    @invalid = RateBeer::Style.new(12345)
    @with_name = RateBeer::Style.new(11, "Barleywine")
    @all_styles = RateBeer::Style.all_styles
  end

  describe ".all_styles" do
    it "lists all styles" do
      expect(@all_styles).to be_an Array
    end

    it "creates a list containing RateBeer::Style instances" do
      @all_styles.each { |s| expect(s).to be_a RateBeer::Style }
    end
  end

  describe "#new" do
    it "creates a style instance" do
      expect(@valid).to be_a RateBeer::Style
    end

    it "requires an ID# as parameter" do
      expect { RateBeer::Style.new }.to raise_error(ArgumentError)
    end

    it "accepts a name parameter" do
      expect(@with_name).to be_a RateBeer::Style
    end
  end

  describe "#name" do
    it "retrives name from RateBeer if not passed as parameter" do
      expect(@valid.name).to eq "Abt/Quadrupel"
    end

    it "uses name details if passed as parameter" do
      expect(@with_name.name).to eq "Barleywine"
    end
  end

  describe "#full_details" do
    it "returns full information about the style" do
      expect(@valid.full_details).to include(:id,
                                             :name,
                                             :description,
                                             :glassware,
                                             :beers)
    end

    it "raises error when invalid ID# passed" do
      expect { @invalid.full_details }.to raise_error(RateBeer::Scraping::PageNotFoundError)
    end
  end
end
