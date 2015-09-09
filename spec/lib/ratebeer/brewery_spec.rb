require 'spec_helper'

describe RateBeer::Brewery do
  before :all do
    @valid     = RateBeer::Brewery.new(8534) # ID for BrewDog
    @with_name = RateBeer::Brewery.new(1069, name: "Cantillon Brewery")
  end

  describe "#new" do
    it "creates a brewery instance" do
      expect(@valid).to be_a RateBeer::Brewery
    end

    it "requires an ID# as parameter" do
      expect { RateBeer::Brewery.new }.to raise_error(ArgumentError)
    end

    it "accepts a name parameter" do
      expect(@with_name).to be_a RateBeer::Brewery
    end
  end

  describe "#name" do
    it "retrieves name from RateBeer if not passed as parameter" do
      expect(@valid.name).to eq "BrewDog"
    end

    it "uses name details if passed as parameter" do
      expect(@with_name.name).to eq "Cantillon Brewery"
    end
  end

  describe "#beers" do
    it "returns a non-empty array of beers produced by the brewery" do
      expect(@valid.beers).to_not be_empty
    end

    it "returns an array of beer instances" do
      @valid.beers.each { |b| expect(b).to be_a RateBeer::Beer }
    end

    it "returns a list of beers produced by brewery" do
      beers = [215065, 98242, 172237, 76701, 178585, 162521, 87321, 118987, 
               119594].map { |id| RateBeer::Beer.new(id) }
      expect(@valid.beers).to include(*beers)
    end
  end

  describe "#full_details" do
    it "returns full information about the brewery" do
      expect(@valid.full_details).to include(:id,
                                             :name,
                                             :url,
                                             :type,
                                             :address,
                                             :telephone,
                                             :beers)
    end
  end
end
