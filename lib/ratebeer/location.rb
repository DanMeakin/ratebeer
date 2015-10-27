require_relative "brewery"
require_relative "style"
require_relative "urls"

module RateBeer
  class Location
    # Keys for fields scraped on RateBeer
    def self.data_keys
      [:name,
       :num_breweries,
       :top_styles,
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
      if location_type.nil? || !([:country, :region].include?(location_type))
        raise ArgumentError.new("location_type must be supplied and must be "\
                                "either country or region")
      end
      @location_type = location_type
    end

    private

    # Retrive details about this location from the website.
    #
    # This method stores the retrived details in instance variables
    # of the location instance.
    #
    def retrieve_details
      doc          = noko_doc(url)
      style_info   = doc.css('#tagside p').first
      heading      = doc.css('.col-lg-9').first
      brewery_info = doc.css('#tabs table')

      @name = heading.at_css('h1')
                     .text
                     .split('Breweries')
                     .first
                     .strip
      if @name == "n/a" || @name == "RateBeer Robot Oops!"
        raise PageNotFoundError.new("#{self.class.name} not found - #{id}")
      end

      @num_breweries = heading.at_css('li.active')
                              .text
                              .scan(/Active \((\d*)\)/)
                              .first
                              .first
                              .to_i
      summary        = doc.at_css("#tagside")
                          .at_css('h3')
                          .next_element
                          .children
                          .select(&:text?)
                          .map { |entry| 
                            [:type, 
                             :count].zip(entry.text
                                              .split('-')
                                              .map { |z| (z.to_i.zero? ?
                                                          z : 
                                                          z.to_i) }) }

      @styles = style_info.children
                         .each_slice(3)
                         .map { |(style, count, _)|
                           id    = style['href'].split('/').last
                           name  = style.text
                           count = count.text.gsub(nbsp, '').to_i
                           Style.new(id, name: name)
                         }

      @breweries = brewery_info.flat_map.with_index do |tbl, i|
        status = i == 0 ? 'Active' : 'Out of Business'

        tbl.css('tr').flat_map do |row|
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
          established = status == 'Active' ? cells[4].text.to_i : nil
          Brewery.new(id,
                      name:        name,
                      location:    location,
                      type:        type,
                      established: established,
                      status:      status)
        end
      end
      nil
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
                 raise "invalid location type: #{@location_type.to_s}"
               end
    end
  end
end
