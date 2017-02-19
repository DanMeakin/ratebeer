# frozen_string_literal: true

require_relative 'beer/alias'
require_relative 'brewery'
require_relative 'review'
require_relative 'style'
require_relative 'scraping'
require_relative 'urls'

module RateBeer
  module Beer
    # The Beer class.
    #
    # This class represents one beer found on RateBeer.com, and provides
    # functionality for obtaining information from the site.
    #
    # The key functionality is defined in the self.data_keys method, each key
    # representing a piece of accessible data.
    class Beer
      # Each key represents an item of data accessible for each beer. The
      # included scraping module defines dynamically a series of methods for
      # accessing this data.
      #
      def self.data_keys
        [:name,
         :brewery,
         :style,
         :glassware,
         :abv,
         :description,
         :retired,
         :rating]
      end

      include RateBeer::Beer
      include RateBeer::Scraping
      include RateBeer::URLs

      # CSS selector for the root element containing beer information.
      ROOT_SELECTOR = '#container table'

      # CSS selector for the beer information element.
      INFO_SELECTOR = 'table'

      # Create RateBeer::Beer instance.
      #
      # Requires the RateBeer ID# for the beer in question.
      #
      # @param [Integer, String] id ID# of beer to retrieve
      # @param [String] name Name of the beer to which ID# relates if known
      # @param [hash] options Options hash for entity created
      #
      def initialize(id, name: nil, **options)
        super
      end

      def doc
        unless instance_variable_defined?('@doc')
          @doc = noko_doc(URI.join(BASE_URL, beer_url(id)))
          validate_beer
          scrape_name # Name must be scraped before any possible redirection.
          @doc = redirect_if_alias(@doc) || @doc
        end
        @doc
      end

      def root
        @root ||= doc.at_css(ROOT_SELECTOR)
      end

      def info_root
        @info_root ||= root.at_css(INFO_SELECTOR)
      end

      # Return reviews of this beer.
      #
      def reviews(order: :most_recent, limit: 10)
        Review.retrieve(self, order: order, limit: limit)
      end

      private

      def validate_beer
        error_indicator = 'we didn\'t find this beer'
        error_message = "Beer not found - #{id}"
        raise PageNotFoundError, error_message if name == error_indicator
      end

      def scrape_name
        @name ||= fix_characters(doc.css('h1').text.strip)
      end

      def scrape_brewery
        brewery_element = doc.at_css("a[itemprop='brand']")
        brewery_id = id_from_link(brewery_element)
        brewery_name = fix_characters(brewery_element.text)
        @brewery = Brewery.new(brewery_id, name: brewery_name)
      end

      def scrape_style
        style_element = doc.at_css("a[href^='/beerstyles']")
        style_id = id_from_link(style_element)
        style_name = fix_characters(style_element.text)
        @style = Style.new(style_id, name: style_name)
      end

      def scrape_glassware
        glassware_elements = doc.css("a[href^='/ShowGlassware.asp']")
        @glassware = glassware_elements.map do |el|
          [:id, :name].zip([el['href'].split('GWID=').last.to_i, el.text]).to_h
        end
      end

      def scrape_abv
        @abv = scrape_misc[:abv]
      end

      def scrape_description
        @description = fix_characters(doc.at_css('#_description3').text)
      end

      def scrape_retired
        element = doc.at_css('span.beertitle2')
        @retired = element && element.text.match?(/RETIRED/) || false
      end

      def scrape_rating
        raw_rating = [:overall,
                      :style].zip(doc.css('#_aggregateRating6 div')
                             .select { |d| d['title'] =~ /This figure/ }
                             .map { |d| d['title'].split(':').first.to_f }).to_h
        @rating = raw_rating.merge(ratings:       scrape_misc[:ratings],
                                   weighted_avg:  scrape_misc[:weighted_avg],
                                   mean:          scrape_misc[:mean])
      end

      # Scrapes the miscellaneous information contained on the beer page.
      #
      # This information relates to various other specific types of information.
      # As such, other scrapers rely on this method for information.
      def scrape_misc
        doc.at_css('.stats-container')
           .children
           .map(&:text)
           .flat_map { |x| x.gsub(nbsp, ' ').strip.split(':') }
           .map(&:strip)
           .reject(&:empty?)
           .each_slice(2)
           .map { |(k, v)| [symbolize_text(k), v.to_f.zero? ? v : v.to_f] }
           .to_h
      end
    end
  end
end
