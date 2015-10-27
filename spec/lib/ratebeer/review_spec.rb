require 'spec_helper'

describe RateBeer::Review do
  before :all do
    @beer = RateBeer::Beer.new(135361) # BrewDog Punk IPA
    @constructed_params = { beer: @beer,
                            reviewer: "Johnny Tester", 
                            reviewer_rank: 1234,
                            location: "The Moon",
                            date: Date.today,
                            rating: 4.00,
                            rating_breakdown: { overall: Rational(20, 20),
                                                aroma: Rational(7, 10),
                                                appearance: Rational(4, 5),
                                                taste: Rational(9, 10),
                                                palate: Rational(3, 5) },
                            comment: "Specimen review of this beer."}
    @constructed = RateBeer::Review.new(@constructed_params)
  end

  describe "#retrieve" do
    before :all do
      @retrieved     = RateBeer::Review.retrieve(@beer)
      # Test ordering
      @recent        = RateBeer::Review.retrieve(@beer, order: :most_recent)
      @top_raters    = RateBeer::Review.retrieve(@beer, order: :top_raters)
      @highest_score = RateBeer::Review.retrieve(@beer, order: :highest_score)
      # Test limit
      @single_review = RateBeer::Review.retrieve(@beer, limit: 1)
      @many_reviews  = RateBeer::Review.retrieve(@beer, limit: 100)
    end

    it "retrieves reviews for the specified beer" do
      @retrieved.each { |r| expect(r).to be_a RateBeer::Review }
    end

    it "retrieves ten reviews by default" do
      expect(@retrieved.length).to eq 10
    end

    it "retrieves the most recent reviews by default" do
      expect(@retrieved).to match_array @recent
    end

    it "retrieves the most recent reviews on request" do
      @recent.each_cons(2).each { |r1, r2|
        expect(r1.date).to be >= r2.date
      }
    end

    it "retrieves reviews by the top raters on request" do
      @top_raters.each_cons(2).each { |r1, r2| 
        expect(r1.reviewer_rank).to be >= r2.reviewer_rank 
      }
    end

    it "retrieves the highest rated reviews on request" do
      @highest_score.each_cons(2).each { |r1, r2|
        expect(r1.rating).to be >= r2.rating
      }
    end
  end

  describe "#new" do
    it "creates a review instance" do
      expect(@constructed).to be_a RateBeer::Review
    end

    it "requires a full set of parameters" do
      params = { beer: @beer, 
                 reviewer: "Johnny Tester",
                 date: Date.today } # Rating & comment missing
      expect { RateBeer::Review.new(params) }.to raise_error(ArgumentError)
    end
  end

  describe "#reviewer" do
    it "returns the name of the reviewer of the beer" do
      expect(@constructed.reviewer).to eq @constructed_params[:reviewer]
    end
  end

  describe "#beer" do
    it "returns the beer reviewed" do
      expect(@constructed.beer).to eq @constructed_params[:beer]
    end
  end

  describe "#date" do
    it "returns the date of the review" do
      expect(@constructed.date).to eq @constructed_params[:date]
    end
  end

  describe "#rating" do
    it "returns the rating of the beer" do
      expect(@constructed.rating).to eq @constructed_params[:rating]
    end
  end

  describe "#rating_breakdown" do
    it "returns the broken-down rating of the beer" do
      expect(@constructed.rating_breakdown).to eq @constructed_params[:rating_breakdown]
    end
  end

  describe "#comment" do
    it "returns the comment attached to the review" do
      expect(@constructed.comment).to eq @constructed_params[:comment]
    end
  end
end
