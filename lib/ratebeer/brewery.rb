require_relative 'scraping'
require_relative 'urls'

module RateBeer
  class Brewery
    include RateBeer::Scraping
    include RateBeer::URLs

    attr_reader :id

    # Create RateBeer::Brewery instance.
    #
    # Requires the RateBeer ID# for the brewery in question. Optionally accepts
    # a name parameter where the name is already known.
    # 
    # @param [Integer, String] id ID# for the brewery
    # @param [String] name The name of the specified brewery
    #
    def initialize(id, name=nil)
      @id   = id
      @name = name unless name.nil?
    end

    def inspect
      val = "#<RateBeer::Brewery ##{@id}"
      val << " - #{@name}" if instance_variable_defined?("@name")
      val << ">"
    end

    def to_s
      inspect
    end

    def url
      @url ||= brewery_url(id)
    end

    # Return full details of the brewery, in a Hash.
    #
    def full_details
      { id:         id,
        name:       name,
        url:        url,
        type:       type,
        address:    address,
        telephone:  telephone,
        beers:      beers }
    end

    [:name,
     :type,
     :address,
     :telephone,
     :beers].each do |attr|
      define_method(attr) do
        unless instance_variable_defined?("@#{attr}")
          retrieve_details
        end
        instance_variable_get("@#{attr}")
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
      @beers = root.css('tr').drop(1).map do |row|
        if row.text =~ /^Brewed at (?<location>.+?)(?: by\/for (?<brewer>.+))?$/
          location = Regexp.last_match['location']
          brewer   = Regexp.last_match['brewer']
        else
          beer = [:name,                 
                  :abv, 
                  :avg_rating, 
                  :overall_rating, 
                  :style_rating, 
                  :num_ratings].zip([0, 2, 3, 4, 5, 6].map { |x|
                         row.css('td')[x].text.gsub(nbsp, ' ').strip 
                  }).to_h
          url  = row.css('td').first.css('a').first['href']
          beer[:name] = fix_characters(beer[:name])
          beer[:url]  = url
          beer[:id]   = url.split('/').last

          # Convert numbers where needed
          [:abv, 
           :avg_rating].each { |k| beer[k] = beer[k].to_f }
          [:overall_rating, 
           :style_rating, 
           :num_ratings,
           :id].each { |k| beer[k] = beer[k].to_i }

          # Apply additional location and brewer information if scraped
          beer[:brewed_at]     = location unless location.nil?
          beer[:brewed_by_for] = brewer unless brewer.nil?
        end
        Beer.new(beer[:id], beer[:name]) || nil
      end.reject(&:nil?)
    end
  end
end
