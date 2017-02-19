require 'spec_helper'

describe RateBeer::Region do
  before :all do
    @region    = RateBeer::Region.new(30) # New Jersey
    @invalid   = RateBeer::Region.new(12345) # Invalid
    @with_name = RateBeer::Region.new(79, name: "London") # Greater London
  end

  describe "#new" do
    it "creates a new region instance" do
      expect(@region).to be_a RateBeer::Region
    end

    it "requires an ID# as parameter" do
      expect { RateBeer::Region.new }.to raise_error(ArgumentError)
    end

    it "accepts a name parameter" do
      expect(@with_name).to be_a RateBeer::Region
    end
  end

  describe "#name" do
    it "retrives name from RateBeer if not passed as parameter" do
      expect(@region.name).to eq 'New Jersey'
    end

    it "uses name details if passed as parameter" do
      expect(@with_name.name).to eq "London"
    end
  end

  describe "#breweries" do
    it "lists breweries within the region" do
      expect(@region.breweries).to be_an Array
    end

    it "returns a series of RateBeer::Brewery instances" do
      expected_breweries = [25_211,
                            3132,
                            1097].map { |i| RateBeer::Brewery::Brewery.new(i) }
      expect(@region.breweries).to include(*expected_breweries)
    end

  end 

  describe "#full_details" do
    it "raises error when invalid ID# passed" do
      expect { @invalid.full_details }.to raise_error(RateBeer::Scraping::PageNotFoundError)
    end

    it "returns full information about this region" do
      expect(@region.full_details).to_not be_empty
    end

    it "returns a hash with specified keys" do
      expect(@region.full_details).to include(:id,
                                              :name,
                                              :url,
                                              :num_breweries,
                                              :breweries)
    end
  end
end
