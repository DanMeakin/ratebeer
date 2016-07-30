require 'spec_helper'

describe RateBeer do
  describe '.beer' do
    it 'creates a new beer' do
      beer = RateBeer.beer(1234, 'Magic Lager')
      expect(beer).to eq RateBeer::Beer.new(1234, name: 'Magic Lager')
    end
  end

  describe '.brewery' do
    it 'creates a new brewery' do
      brewery = RateBeer.brewery(456, 'Magic BrewCo')
      expect(brewery).to eq RateBeer::Brewery.new(456, name: 'Magic BrewCo')
    end
  end

  describe '.style' do
    it 'creates a new style' do
      style = RateBeer.style(99, 'Butter Beer')
      expect(style).to eq RateBeer::Style.new(99, name: 'Butter Beer')
    end
  end

  describe '.search' do
    it 'runs a new search query' do
      actual = RateBeer.search('pabst blue ribbon')
      expected = RateBeer::Search.search('pabst blue ribbon')
      expect(expected).to eq actual
    end
  end
end
