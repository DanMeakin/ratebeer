require 'spec_helper'

describe RateBeer::Beer::Review do
  before :all do
    # Create Review instance with Beer instance
    @chunks = ['4.00 AROMA 7/10 APPEARANCE 4/5 TASTE 9/10 PALATE 3/5 OVERALL 20/20',
               'Johnny Tester (1234) - The Moon - SEP 8, 2013',
               'Specimen review of this beer.']
    @reviewer = 'Johnny Tester'
    @rank = '1234'
    @location = 'The Moon'
    @date = Date.new(2013, 9, 8)
    @rating = 4.00
    @rating_breakdown = { overall: Rational(20, 20),
                          aroma: Rational(7, 10),
                          appearance: Rational(4, 5),
                          taste: Rational(9, 10),
                          palate: Rational(3, 5) }
    @comment = 'Specimen review of this beer.'
    @review = RateBeer::Beer::Review.new(@chunks)
  end

  describe "#new" do
    it "creates a review instance" do
      expect(@review).to be_a RateBeer::Beer::Review
    end
  end

  describe "#reviewer" do
    it "returns the name of the reviewer of the beer" do
      expect(@review.reviewer).to eq @reviewer
    end
  end

  describe "#date" do
    it "returns the date of the review" do
      expect(@review.date).to eq @date
    end
  end

  describe "#rating" do
    it "returns the rating of the beer" do
      expect(@review.rating).to eq @rating
    end
  end

  describe "#rating_breakdown" do
    it "returns the broken-down rating of the beer" do
      expect(@review.rating_breakdown).to eq @rating_breakdown
    end
  end

  describe "#comment" do
    it "returns the comment attached to the review" do
      expect(@review.comment).to eq @comment
    end
  end
end
