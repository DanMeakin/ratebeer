require_relative 'beer'
require_relative 'scraping'
require_relative 'urls'

module RateBeer
  class Style
    # Each key represents an item of data accessible for each beer, and defines
    # dynamically a series of methods for accessing this data.
    #
    def self.data_keys
      [:name,
       :description,
       :glassware,
       :beers]
    end

    include RateBeer::Scraping
    include RateBeer::URLs

    attr_accessor :category

    class << self
      include RateBeer::URLs

      # Scrape all styles.
      #
      # RateBeer provides a styles landing page, with links through to info on
      # each style listed thereon. This method scrapes style info with links
      # to the more detailed pages.
      #
      # @param [Boolean] hidden_styles Flag for whether to include hidden
      #   styles.
      # @return [Array<RateBeer::Style>] List of styles with links etc. to
      #   detailed pages
      #
      def all_styles(include_hidden = false)
        doc  = Scraping.noko_doc(URI.join(BASE_URL, '/beerstyles/'))
        root = doc.at_css('div.container-fluid')

        categories = root.css('h3').map(&:text)
        style_node = root.css('.styleGroup')

        styles = style_node.flat_map.with_index do |list, i|
          list.css('a').map do |x|
            category = categories[i]
            Style.new(x['href'].split('/').last.to_i, name: x.text).tap do |s|
              s.category = category
            end
          end
        end
        if include_hidden
          styles + hidden_styles
        else
          styles
        end
      end
      
      # Scrape hidden style information
      #
      # RateBeer has a number of styles not accessible from the "beerstyles"
      # landing page. This method scrapes these.
      #
      # @return [Array<Hash>] List of hidden styles
      #
      def hidden_styles
        hidden_ids = [40, 41, 57, 59, 66, 67, 68, 69, 70,
                      75, 83, 99, 104, 106, 116, 119, 120]
        hidden_ids.map do |id|
          Style.new(id)
        end
      end
    end

    private

    def doc
      unless instance_variable_defined?('@doc')
        @doc = noko_doc(URI.join(BASE_URL, style_url(id)))
        validate_style
      end
      @doc
    end

    def validate_style
      raise PageNotFoundError.new("style not found - ##{id}") if root.nil?
    end

    def root
      @root ||= doc.at_css('.container-fluid')
    end

    def beer_list
      @beer_list = noko_doc(URI.join(BASE_URL, style_beers_url(id)))
    end

    def scrape_name
      @name = root.at_css('h1').text.strip
    end

    def scrape_description
      @description = root.at_css('#styleDescription').text
    end

    def scrape_glassware
      @glassware   = root.css('.glassblurb').map { |x| x.text.strip }
    end

    def scrape_beers
      @beers = beer_list.css('tr').drop(1).map do |row|
        cells = row.css('td')
        url   = cells[1].at_css('a')['href']
        [cells[0].text.to_i, Beer::Beer.new(url.split('/').last,
                                            name: fix_characters(cells[1].text))]
      end.to_h
    end
  end
end
