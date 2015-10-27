require_relative "scraping"
require_relative "urls"

module RateBeer
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

    private

    # Retrieve details about this brewery from the website.
    #
    # This method stores the retrieved details in instance variables
    # of the brewery instance.
    #
    def retrieve_details
      @doc  = noko_doc(URI.join(BASE_URL, brewery_url(id)))

      brewery_info = retrieve_brewery_info

      @beers = []
      if pagination?(@doc)
        (1..page_count(@doc)).flat_map do |page_no|
          @doc = noko_doc(URI.join(BASE_URL, brewery_url(id), "0/", "#{page_no}/"))
          retrieve_brewery_beers
        end
      else
        retrieve_brewery_beers
      end
      nil
    end

    # Scrape brewery info from Nokogiri Doc for brewery page
    #
    def retrieve_brewery_info
      root = @doc.css('#container table').first
      contact_node = root.css('td').first

      @name = fix_characters(root.css('h1').first.text)
      raise PageNotFoundError.new("Brewery not found - #{id}") if @name.empty?

      @type = root.css('span.beerfoot')
                  .select { |x| x.text =~ /Type: .*/ }
                  .first
                  .text
                  .strip
                  .split("Type: ")
                  .last
                  .split(/\s{2,}/)
                  .first
      @address = root.css('div[itemprop="address"] b span')
                     .map { |elem| key = case elem.attributes['itemprop'].value
                                         when 'streetAddress' then :street
                                         when 'addressLocality' then :city
                                         when 'addressRegion' then :state
                                         when 'addressCountry' then :country
                                         when 'postalCode' then :postcode
                                         else raise "unrecognised attribute"
                                         end
                                   [key, elem.text.strip] }
                     .to_h

      @telephone = root.css('span[itemprop="telephone"]').first && 
                   root.css('span[itemprop="telephone"]').first.text

    end

    # Scrape beer details from Nokogiri Doc for brewery page
    #
    def retrieve_brewery_beers
      location, brewer = nil  # Variables used in the map below
      root = @doc.css('table.maintable.nohover').first
      @beers += root.css('tr').drop(1).map do |row|
        if row.text =~ /^Brewed at (?<location>.+?)(?: by\/for (?<brewer>.+))?$/
          location = Regexp.last_match['location']
          brewer   = Regexp.last_match['brewer']
          nil
        else
          process_beer_row(row, location, brewer)
        end
      end.reject(&:nil?)
    end

    # Process a row of data representing one beer brewed by/at a brewery.
    #
    # @param [Nokogiri::XML::Element] row HTML TR row wrapped as a Nokogiri
    #   element
    # @param [String] location the location at which a brewery's beer is brewed
    #   where this location differs from the brewery's regular brewsite/venue
    # @param [String] brewer the client for whom this brewery brewed the beer,
    #   where the brewery is brewing for a different company/brewery
    # @return [RateBeer::Beer] a beer object representing the scraped beer, 
    #   containing scraped attributes
    #
    def process_beer_row(row, location=nil, brewer=nil)
      # Attributes stored in each table row, with indices representing their
      # position in each row
      attributes = { name:            0,
                     abv:             2,
                     avg_rating:      3,
                     overall_rating:  4,
                     style_rating:    5,
                     num_ratings:     6 }

      beer = attributes.reduce({}) do |beer_hash, (attr, i)| 
        val = row.css('td')[i].text.gsub(nbsp, ' ').strip rescue nil
        case attr
        when :name
          fix_characters(val)
        when :abv, :avg_rating
          val = val.to_f
        when :overall_rating, :style_rating, :num_ratings
          val = val.to_i
        end
        beer_hash[attr] = val
        beer_hash
      end
      beer[:url] = row.css('td').first.css('a').first['href']
      id = beer[:url].split('/').last.to_i

      # Apply additional location and brewer information if scraped
      beer[:brewed_at]     = location unless location.nil?
      beer[:brewed_by_for] = brewer unless brewer.nil?

      # Create beer instance from scraped data
      Beer.new(id, beer)
    end
  end
end
