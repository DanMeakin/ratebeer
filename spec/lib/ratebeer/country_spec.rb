require 'spec_helper'

describe RateBeer::Country do
  before :all do
    @country   = RateBeer::Country.new(241) # Scotland
    @invalid   = RateBeer::Country.new(12345) # Invalid
    @with_name = RateBeer::Country.new(14, name: "Oceania - Australia") # Australia
  end

  describe "#new" do
    it "creates a new country instance" do
      expect(@country).to be_a RateBeer::Country
    end

    it "requires an ID# as parameter" do
      expect { RateBeer::Country.new }.to raise_error(ArgumentError)
    end

    it "accepts a name parameter" do
      expect(@with_name).to be_a RateBeer::Country
    end
  end

  describe "#name" do
    it "retrives name from RateBeer if not passed as parameter" do
      expect(@country.name).to eq "Scotland"
    end

    it "uses name details if passed as parameter" do
      expect(@with_name.name).to eq "Oceania - Australia"
    end
  end

  describe "#breweries" do
    it "lists breweries within the country" do
      expect(@country.breweries).to be_an Array
    end

    it "returns a series of RateBeer::Brewery instances" do
      expected_breweries = [19163,
                            2809,
                            2878,
                            11582,
                            8031].map { |i| RateBeer::Brewery.new(i) }
      expect(@country.breweries).to include(*expected_breweries)
    end

  end 

  describe "#full_details" do
    it "raises error when invalid ID# passed" do
      expect { @invalid.full_details }.to raise_error(RateBeer::Scraping::PageNotFoundError)
    end

    it "returns full information about this country" do
      expect(@country.full_details).to_not be_empty
    end

    it "returns a hash with specified keys" do
      expect(@country.full_details).to include(:id,
                                               :name,
                                               :url,
                                               :num_breweries,
                                               :breweries)
    end
  end
end
