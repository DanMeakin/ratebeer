# frozen_string_literal: true

require_relative 'scraping'
require_relative 'urls'
require_relative 'brewery/beer_list'

module RateBeer
  # The brewery class represents one brewery found in RateBeer, with methods
  # for accessing information found about the brewery on the site.
  module Brewery
    class Brewery
      # Each key represents an item of data accessible for each beer, and defines
      # dynamically a series of methods for accessing this data.
      #
      def self.data_keys
        [:name,
         :type,
         :address,
         :telephone,
         :beers]
      end

      include RateBeer::Scraping
      include RateBeer::URLs

      attr_reader :established, :location

      # CSS selector for the brewery information element.
      INFO_SELECTOR = "div[itemtype='http://schema.org/LocalBusiness']".freeze

      # Create RateBeer::Brewery instance.
      #
      # Requires the RateBeer ID# for the brewery in question. Optionally accepts
      # a name parameter where the name is already known.
      #
      # @param [Integer, String] id ID# for the brewery
      # @param [String] name The name of the specified brewery
      # @param [hash] options Options hash for entity created
      #
      def initialize(id, name: nil, **options)
        super
        if options
          @established = options[:established]
          @location    = options[:location]
          @type        = options[:type]
          @status      = options[:status]
        end
      end

      def doc
        @doc ||= noko_doc(URI.join(BASE_URL, brewery_url(id)))
        validate_brewery
        @doc
      end

      def info_root
        @info_root ||= doc.at_css(INFO_SELECTOR)
      end

      private

      # Validates whether the brewery with the given ID exists.
      #
      # Throws an exception if the brewery does not exist.
      def validate_brewery
        error_message = "This brewer, ID##{id}, is no longer in the database. "\
                        'RateBeer Home'
        if @doc.at_css('body p').text == error_message
          raise PageNotFoundError.new("Brewery not found - #{id}")
        end
      end

      # Scrapes the brewery's name.
      def scrape_name
        @name = fix_characters(info_root.css('h1').first.text)
      end

      # Scrapes the brewery's address.
      def scrape_address
        address_root = info_root.css('div[itemprop="address"] b span')
        address_details = address_root.map { |e| extract_address_element(e) }
        @address = address_details.to_h
      end

      # Extracts one element of address details from a node contained within the
      # address div.
      def extract_address_element(node)
        key = case node.attributes['itemprop'].value
              when 'streetAddress'   then :street
              when 'addressLocality' then :city
              when 'addressRegion'   then :state
              when 'addressCountry'  then :country
              when 'postalCode'      then :postcode
              else raise 'unrecognised attribute'
              end
        [key, node.text.strip]
      end

      # Scrapes the telephone number of the brewery.
      def scrape_telephone
        @telephone = info_root.at_css('span[itemprop="telephone"]')
      end

      # Scrapes the type of brewery.
      def scrape_type
        @type = info_root.css('div')[1]
      end

      # Scrapes beers list for brewery.
      def scrape_beers
        @beers = BeerList.new(self).beers
      end
    end
  end
end
