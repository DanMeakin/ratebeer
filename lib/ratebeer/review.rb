require_relative "beer"
require_relative "scraping"
require_relative "urls"

module RateBeer
  # The Review class contains reviews of Beers posted to RateBeer.com. It
  # also provides some scraping functionality for obtaining reviews.
  #
  class Review
    extend RateBeer::URLs

    class << self
      attr_reader :review_limit
      attr_reader :review_order
    
      # Calculate the number of pages of reviews to retrieve.
      #
      # Ten reviews appear on a page, so this method calculates the number of
      # pages on this basis.
      #
      # @param [Integer] limit The number of reviews to be retrieved
      # @return [Integer] Number of pages to be retrieved for number of reviews
      #
      def num_pages(limit)
        (limit / 10.0).ceil
      end

      # Determine the URL suffix required for a particular sort order.
      #
      # @param [Symbol] order The desired sorting order
      # @return [String] The URL suffix required to obtain reviews sorted in
      #   the desired order
      #
      def url_suffix(order)
        options = [:most_recent, :top_raters, :highest_score]
        unless options.include?(order)
          raise ArgumentError.new("unknown ordering: #{order}") 
        end

        case order 
        when :most_recent
          "1"
        when :top_raters
          "2"
        when :highest_score
          "3"
        end
      end

      # Retrieve all reviews for a given beer.
      #
      # @param [Integer, RateBeer::Beer] beer The beer for which to download
      #   reviews
      # @param [Symbol] order The order by which to list reviews
      # @param [Integer] limit The number of reviews to retrieve
      # @return [Array<RateBeer::Review>] A list of all reviews for the passed
      #   beer, up to the review_limit
      #
      def retrieve(beer, order: :most_recent, limit: 10)
        if beer.is_a?(RateBeer::Beer::Beer)
          beer_id = beer.id
        elsif beer.is_a?(Integer)
          beer_id = beer
          beer    = RateBeer::Beer::Beer.new(beer)
        else
          raise "unknown beer value: #{beer}"
        end

        reviews = num_pages(limit).times.flat_map do |page_number|
          url = URI.join(BASE_URL, review_url(beer_id, url_suffix(order), page_number))
          doc = RateBeer::Scraping.noko_doc(url)
          root = doc.at_css('.reviews-container')

          # All reviews are contained within the sole cell in the sole row of
          # the selected table. Each review consists of rating information, 
          # details of the reviewer, and the text of the review itself.
          #
          # The components are contained within div, small, div tags 
          # respectively. We need to scrape these specifically.
          root.at_css('div div')
              .children
              .select { |x| x.name == 'div' || x.name == 'small' }
              .map(&:text)
              .reject { |x| x.empty? || x.include?("googleFillSlot") }
              .each_slice(3).map do |(rating_data, reviewer_data, review)|
                rating_pattern   = /^(?<total>\d+(\.\d+)?).+
                                    AROMA\s(?<aroma>\d+\/10).+
                                    APPEARANCE\s(?<appearance>\d+\/5).+
                                    TASTE\s(?<taste>\d+\/10).+
                                    PALATE\s(?<palate>\d+\/5).+
                                    OVERALL\s(?<overall>\d+\/20)$/x
                reviewer_pattern = /^(?<name>.+)\s\((?<rank>\d+\))\s-\s?
                                     (?<location>.+)?\s?-\s
                                     (?<date>.+)$/x
                rating_breakdown_match = rating_data.match(rating_pattern)
                rating_breakdown = {}
                reviewer = reviewer_data.gsub(RateBeer::Scraping.nbsp, ' ').match(reviewer_pattern)
                [:overall, :aroma, :appearance, :taste, :palate].each { |k|
                  rating_breakdown[k] = Rational(rating_breakdown_match[k])
                }
                rating = rating_breakdown_match[:total].to_f
                self.new({ beer:              beer,
                           reviewer:          reviewer[:name],
                           reviewer_rank:     reviewer[:rank],
                           location:          reviewer[:location].strip,
                           date:              Date.parse(reviewer[:date]),
                           rating:            rating,
                           rating_breakdown:  rating_breakdown,
                           comment:           review })
          end
        end
        reviews.take(limit)
      end
    end
    
    attr_reader :beer
    attr_reader :reviewer
    attr_reader :reviewer_rank
    attr_reader :location
    attr_reader :date 
    attr_reader :rating
    attr_reader :rating_breakdown
    attr_reader :comment

    def initialize(**options)
      @beer = if options[:beer].is_a?(RateBeer::Beer)
                options[:beer]
              elsif options[:beer].is_a?(Integer)
                RateBeer::Beer::Beer.new(options[:beer])
              else
                raise ArgumentError.new("incorrect beer parameter: #{options[:beer]}")
              end
      [:reviewer, :reviewer_rank, :location, :date, 
       :rating, :rating_breakdown, :comment].each do |param|
        if options[param].nil?
          raise ArgumentError.new("#{param.to_s} parameter required")
        end
        instance_variable_set("@#{param.to_s}", options[param])
      end
    end

    def inspect
      var = "#<Review of #{self.beer} - #{@reviewer} on #{@date}>"
    end

    def to_s
      inspect
    end

    def ==(other_review)
      self.reviewer == other_review.reviewer && 
        self.date == other_review.date && 
        self.beer == other_review.beer &&
        self.comment == other_review.comment
    end
  end
end
