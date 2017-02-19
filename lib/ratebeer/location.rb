require_relative 'brewery'
require_relative 'style'
require_relative 'urls'

module RateBeer
  class Location
    # Keys for fields scraped on RateBeer
    def self.data_keys
      [:name,
       :num_breweries,
       :breweries]
    end

    include RateBeer::Scraping
    include RateBeer::URLs

    # Initialize a RateBeer::Location instance.
    #
    # Locations may be either Regions or Countries. This must be specified to
    # the constructor.
    #
    # @param [Integer] id ID# for this location
    # @param [Symbol] location_type Symbol representing either country or region
    # @param [String] name Name of this location
    #
    def initialize(id, location_type: nil, name: nil, **options)
      super
      if location_type.nil? || ![:country, :region].include?(location_type)
        raise ArgumentError.new('location_type must be supplied and must be '\
                                'either country or region')
      end
      @location_type = location_type
    end

    def doc
      unless instance_variable_defined?('@doc')
        @doc = noko_doc(url)
        validate_location
      end
      @doc
    end

    private

    def validate_location
      if @doc.at_css('h1').text.include? 'n/a'
        raise PageNotFoundError.new("#{self.class.name} not found - #{id}")
      end
    end

    def scrape_name
      @name = doc.at_css('h1')
                 .text
                 .split('Breweries')
                 .first
                 .strip
    end

    def scrape_num_breweries
      @num_breweries = doc.at_css('li.active')
                          .text
                          .split(' ')
                          .first
                          .to_i
    end

    def scrape_breweries
      brewery_info = doc.css('#tabs table')
      @breweries = brewery_info.flat_map.with_index do |tbl, i|
        status = i == 0 ? 'Active' : 'Out of Business'

        tbl.css('tr').drop(1).flat_map do |row|
          cells = row.css('td')
          next if cells.empty?
          id       = cells[0].at_css('a')['href'].split('/').last.to_i
          name     = cells[0].text.split('-').first.strip
          location = cells[0].text
                             .split('-')
                             .last
                             .sub('(Out of Business)', '')
                             .strip
          type = cells[1].text.strip
          established = status == 'Active' ? cells[3].text.to_i : nil
          Brewery::Brewery.new(id,
                               name:        name,
                               location:    location,
                               type:        type,
                               established: established,
                               status:      status)
        end
      end
    end

    # Return URL for page containing information on this location.
    #
    # Result depends on whether this is a country or a region.
    #
    def url
      @url ||= case @location_type
               when :country
                 URI.join(BASE_URL, country_url(id))
               when :region
                 URI.join(BASE_URL, region_url(id))
               else
                 raise "invalid location type: #{@location_type}"
               end
    end
  end
end
