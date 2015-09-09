module RateBeer
  class Location
    include RateBeer::Scraping
    include RateBeer::URLs

    attr_reader :id

    # Initialize a RateBeer::Location instance.
    #
    # Locations may be either Regions or Countries. This must be specified to
    # the constructor.
    #
    # @param [Integer] id ID# for this location
    # @param [Symbol] location_type Symbol representing either country or region
    # @param [String] name Name of this location
    #
    def initialize(id, location_type, name=nil)
      @id            = id
      @location_type = location_type
      @name          = name unless name.nil?
    end

    def inspect
      val = "#<RateBeer::Location ##{@id} (#{@location_type.to_s})"
      val << " - #{@name}" if instance_variable_defined?("@name")
      val << ">"
    end

    def to_s
      inspect
    end

    def ==(other_location)
      other_location.is_a?(self.class) && id == other_location.id
    end

    def full_details
      { id:             id,
        name:           name,
        url:            url,
        top_styles:     top_styles,
        num_breweries:  num_breweries,
        breweries:      breweries }
    end

    [:name,
     :num_breweries,
     :top_styles,
     :breweries].each do |attr|
      define_method(attr) do
        unless instance_variable_defined?("@#{attr}")
          retrieve_details
        end
        instance_variable_get("@#{attr}")
      end
    end
        
    private

    # Retrive details about this location from the website.
    #
    # This method stores the retrived details in instance variables
    # of the location instance.
    #
    def retrieve_details
      doc          = noko_doc(url)
      root         = doc.css('#container table').first
      style_info   = root.css('#tagside p').first
      heading      = root.css('#brewerCover').first
      brewery_info = root.css('#brewerTable')

      @name = heading.at_css('h1')
                     .text
                     .split('Breweries')
                     .first
                     .strip
      if @name == "n/a"
        raise PageNotFoundError.new("#{self.class.name} not found - #{id}")
      end

      @num_breweries = heading.at_css('#showInfo')
                              .text
                              .split('active')
                              .first
                              .to_i
      summary       = heading.at_css('#hideInfo')
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
                           Style.new(id, name)
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
