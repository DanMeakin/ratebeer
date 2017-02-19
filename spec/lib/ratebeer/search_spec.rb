require 'spec_helper'

describe RateBeer::Search do
  describe '#new' do
    before :all do
      @search = RateBeer::Search.new('Testing Brewers Co Ltd')
    end

    it 'creates a search instance' do
      expect(@search).to be_a RateBeer::Search
    end

    it 'removes generic terms from query parameter' do
      expect(@search.query).to_not include('Brewers')
    end
  end

  describe '#run_search' do
    before :all do
      @failed_search     = RateBeer::Search.new('random param 1234').run_search
      @successful_search = RateBeer::Search.new('dugges').run_search
    end

    it 'executes a search using specified query parameter' do
      expect(@failed_search).to_not be_nil
      expect(@successful_search).to_not be_nil
    end

    it 'returns nil for beers for non-matching query' do
      expect(@failed_search.beers).to be_nil
    end

    it 'returns nil for breweries for non-matching query' do
      expect(@failed_search.breweries).to be_nil
    end

    it 'returns a list of beers matching query parameter' do
      expect(@successful_search.beers.count).to be > 0
    end

    it 'returns a list of breweries matching query parameter' do
      expect(@successful_search.breweries.count).to be > 0
    end

    it 'returns a list of specific beers matching the query parameter' do
      beers = @successful_search.beers
      names = beers.map(&:name)
      expect(names).to include('Dugges / Stillwater Tropic Thunder',
                               'Dugges Almost Imperial',
                               'Dugges Bärliner')
    end

    it 'returns a list of specific breweries matching the query parameter' do
      breweries = @successful_search.breweries
      names     = breweries.map(&:name)
      expect(names).to include('Dugges Bryggeri')
    end
  end
end
