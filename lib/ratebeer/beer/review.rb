# frozen_string_literal: true

require_relative '../beer'
require_relative '../scraping'
require_relative '../urls'

module RateBeer
  module Beer
    # The Review class contains reviews of Beers posted to RateBeer.com. It
    # also provides some scraping functionality for obtaining reviews.
    #
    class Review
      include RateBeer::Scraping
      include RateBeer::URLs

      # Instantiate a Review instance.
      #
      # @param [Nokogiri::HTML] chunk A list of HTML tags containing one review
      #
      def initialize(chunk)
        @rating_data, @reviewer_data, @review = chunk
      end

      def to_s
        inspect
      end

      def inspect
        "#<RateBeer::Beer::Review - #{reviewer} (#{date})"
      end

      def ==(other)
        reviewer == other.reviewer &&
          date == other.date &&
          beer == other.beer &&
          comment == other.comment
      end

      [:reviewer,
       :reviewer_rank,
       :location,
       :date,
       :comment].each do |attr|
        define_method(attr) do
          read_reviewer_data[attr]
        end
      end

      [:rating,
       :rating_breakdown].each do |attr|
        define_method(attr) do
          read_rating_data[attr]
        end
      end

      def comment
        read_comment[:comment]
      end

      private

      RATING_PATTERN = %r{^(?<total>\d+(\.\d+)?).+
                          AROMA\s(?<aroma>\d+/10).+
                          APPEARANCE\s(?<appearance>\d+/5).+
                          TASTE\s(?<taste>\d+/10).+
                          PALATE\s(?<palate>\d+/5).+
                          OVERALL\s(?<overall>\d+/20)$}x

      REVIEWER_PATTERN = /^(?<name>.+)\s\((?<rank>\d+\))\s-\s?
                          (?<location>.+)?\s?-\s
                          (?<date>.+)$/x

      def read_reviewer_data
        reviewer = @reviewer_data.gsub(nbsp, ' ').match(REVIEWER_PATTERN)
        { reviewer:         reviewer[:name],
          reviewer_rank:    reviewer[:rank],
          location:         reviewer[:location].strip,
          date:             Date.parse(reviewer[:date]) }
      end

      def read_rating_data
        rating_breakdown_match = @rating_data.match(RATING_PATTERN)
        rating_breakdown = {}
        [:overall, :aroma, :appearance, :taste, :palate].each do |k|
          rating_breakdown[k] = Rational(rating_breakdown_match[k])
        end
        rating = rating_breakdown_match[:total].to_f
        { rating:           rating,
          rating_breakdown: rating_breakdown }
      end

      def read_comment
        { comment: @review }
      end
    end
  end
end
