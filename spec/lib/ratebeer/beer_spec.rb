require 'spec_helper'

describe RateBeer::Beer do
  before :all do
    @valid     = RateBeer::Beer.new(1411) # ID for Tennents Lager (sorry...)
    @retired   = RateBeer::Beer.new(213225) # ID for BrewDog Vice Bier
    @with_name = RateBeer::Beer.new(422, name: "Stone IPA")
  end

  describe "#new" do
    it "creates a beer instance" do
      expect(@valid).to be_a RateBeer::Beer
    end

    it "requires an ID# as parameter" do
      expect { RateBeer::Beer.new }.to raise_error(ArgumentError)
    end

    it "accepts a name parameter" do
      expect(@with_name).to be_a RateBeer::Beer
    end
  end

  describe "#name" do
    it "retrieves name details from RateBeer if not present" do
      expect(@valid.name).to eq "Tennents Lager"
    end

    it "uses name details if passed as parameter" do
      expect(@with_name.name).to eq "Stone IPA"
    end
  end

  describe "#retired" do
    it "states that beer is retired when this is the case" do
      expect(@valid.retired).to be false
      expect(@retired.retired).to be true
    end
  end

  describe "#full_details" do
    it "returns full information about the beer" do
      expect(@valid.full_details).to include(:id,
                                             :name,
                                             :brewery,
                                             :url,
                                             :style,
                                             :glassware,
                                             :availability,
                                             :abv,
                                             :calories,
                                             :description,
                                             :retired,
                                             :rating)
    end
  end
end
