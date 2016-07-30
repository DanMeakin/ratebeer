require_relative "brewery"
require_relative "review"
require_relative "style"
require_relative "scraping"
require_relative "urls"

module RateBeer
  class Beer
    # Each key represents an item of data accessible for each beer, and defines
    # dynamically a series of methods for accessing this data.
    #
    def self.data_keys
      [:name,
       :brewery,
       :style,
       :glassware,
       :availability,
       :abv,
       :calories,
       :description,
       :retired,
       :rating]
    end

    include RateBeer::Scraping
    include RateBeer::URLs

    # CSS selector for the root element containing beer information.
    ROOT_SELECTOR = '#container table'.freeze

    # CSS selector for the beer information element.
    INFO_SELECTOR = 'table'.freeze

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
      unless instance_variable_defined?("@doc")
        @doc = noko_doc(URI.join(BASE_URL, beer_url(id)))
        validate_beer
        redirect_if_aliased
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

    # Redirects this beer to the "proper" beer page if it represents an alias
    # of another beer.
    #
    # This method overwrites the value of @doc, so that this will scrape the
    # details of the proper beer, and not the alias.
    def redirect_if_aliased
      # retrieve details of the proper beer instead.
      alias_pattern = /Also known as(.|\n)*Proceed to the aliased beer\.{3}/
      local_root = doc.at_css(ROOT_SELECTOR)
      if local_root.css('tr')[1].css('div div').text =~ alias_pattern
        scrape_name # Set the name to the original, non-aliased beer.
        alias_node = local_root.css('tr')[1]
                               .css('div div')
                               .css('a')
                               .first
        @alias_id = alias_node['href'].split('/').last.to_i
        @doc = noko_doc(URI.join(BASE_URL, beer_url(@alias_id)))
      end
    end

    def validate_beer
      error_message = 'we didn\'t find this beer'
      if name == error_message
        raise PageNotFoundError.new("Beer not found - #{id}")
      end
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

    def scrape_availability
      raw_info = info_root.css('td')[1]
                          .css('table')
                          .css('td')
                          .children
                          .children
                          .map(&:text)
                          .reject(&:empty?)
                          .each_slice(2)
                          .to_a
                          .tap { |a| a.last.unshift('distribution') }
                          .map do |(k, v)|
        [k =~ /bottl/ ? :bottling : symbolize_text(k), v]
      end
      @availability = raw_info.to_h.merge(seasonal: scrape_misc[:seasonal])
    end

    def scrape_abv
      @abv = scrape_misc[:abv]
    end

    def scrape_calories
      @calories = scrape_misc[:est_calories]
    end

    def scrape_description
      @description = info_root.next_element
                              .next_element
                              .children
                              .children
                              .map(&:text)
                              .map(&:strip)
                              .drop(1)
                              .reject(&:empty?)
                              .join("\n")
      @description = fix_characters(@description)
    end

    def scrape_retired
      @retired = !(root.css('span.beertitle2') && 
                   root.css('span.beertitle2').text =~ /RETIRED/).nil?  
    end

    def scrape_rating
      raw_rating = [:overall,
                    :style].zip(info_root.css('div')
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
      info_root.next_element
               .first_element_child
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
