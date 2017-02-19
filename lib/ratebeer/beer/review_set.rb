# frozen_string_literal: true

require_relative '../beer'
require_relative '../scraping'
require_relative '../urls'

module RateBeer
  module Beer
    # The Review class contains reviews of Beers posted to RateBeer.com. It
    # also provides some scraping functionality for obtaining reviews.
    #
    class ReviewSet
      include RateBeer::Scraping
      include RateBeer::URLs

      ORDERINGS = { most_recent:    1,
                    top_raters:     2,
                    highest_score:  3 }.freeze

      # Instantiate a ReviewSet.
      #
      # @param [RateBeer::Beer::Beer] beer The beer for which to obtain reviews
      # @param [Integer] limit_size The maximum number of views to retrieve
      def initialize(beer, limit_size: 10, review_order: :most_recent)
        @beer = beer
        @limit = limit_size
        @review_order = review_order
      end

      def doc
        construct_doc unless instance_variable_defined?('@doc')
      end

      def reviews
        review_chunks.map { |c| Review.new(c) }
      end

      private

      # Generate the Nokogiri doc for this review set.
      #
      # This is different from other doc functions, in that reviews are
      # paginated. The doc is formed by concatenating together the relevant
      # parts of each page, ready for parsing.
      #
      def construct_doc
        @doc = num_pages.times.map do |page_number|
          url = URI.join(BASE_URL,
                         review_url(@beer.id, url_suffix, page_number))
          noko_doc(url).at_css('.reviews-container')
        end
      end

      # Split the doc into chunks, each of which contains one review.
      #
      def review_chunks
        doc.flat_map do |page|
          page.css('div div')
              .children
              .select { |x| x.name == 'div' || x.name == 'small' }
              .map(&:text)
              .reject { |x| x.empty? || x.include?('googleFillSlot') }
              .each_slice(3)
              .take(@limit)
        end
      end

      # Calculate the number of pages of reviews to retrieve.
      #
      # Ten reviews appear on a page, so this method calculates the number of
      # pages on this basis.
      #
      # @param [Integer] limit The number of reviews to be retrieved
      # @return [Integer] Number of pages to be retrieved for number of reviews
      #
      def num_pages
        (@limit / 10.0).ceil
      end

      # Determine the URL suffix required for a particular sort order.
      #
      # @param [Symbol] order The desired sorting order
      # @return [String] The URL suffix required to obtain reviews sorted in
      #   the desired order
      #
      def url_suffix
        suffix = ORDERINGS[@review_order]
        raise ArgumentError, "unknown ordering: #{@review_order}" if suffix.nil?
        suffix
      end
    end
  end
end
