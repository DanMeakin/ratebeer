require 'i18n'
require 'thread'
require_relative 'beer'
require_relative 'brewery'
require_relative 'scraping'
require_relative 'urls'

module RateBeer
  # Stop I18N from enforcing locale, to avoid error message
  I18n.enforce_available_locales = false

  # This class provides functionality for searching RateBeer.com for a
  # specific beer or brewery.
  #
  class Search
    # Keys for fields scraped on RateBeer
    def self.data_keys
      [:query,
       :beers,
       :breweries]
    end

    include RateBeer::Scraping
    include RateBeer::URLs

    class << self
      # Create method which generates new search instance and immediately runs
      # a search.
      #
      def search(query)
        s = new(query)
        { beers:      s.beers,
          breweries:  s.breweries }
      end
    end

    attr_reader :query

    # Create a RateBeer::Search instance.
    #
    # @param [String] query Term to use to search RateBeer
    #
    def initialize(query, scrape_beer_brewers = false)
      self.query = query
      @scrape_breweries = scrape_beer_brewers
    end

    # Setter for query instance variable.
    #
    def query=(qry)
      clear_cached_data
      @query = fix_query_param(qry)
    end

    def ==(other)
      query == other.query
    end

    def inspect
      num_beers = @beers && @beers.count || 0
      num_breweries = @breweries && @breweries.count || 0
      val = "#<#{self.class} - #{@query}"
      val << " - #{num_beers} beers / #{num_breweries} breweries" if @beers || @breweries
      val << ">"
    end

    # Search RateBeer for beers, brewers, etc.
    #
    # The search results page contains a series of tables each of which has the
    # "results" class, containing data of matching brewers, beers, and places
    # in that order. Only brewers and beers are extracted.
    #
    # @return [Hash] Results of the search, broken into breweries and beers,
    #                with the attributes of these results contained therein.
    #
    def run_search
      @beers, @breweries = nil
      tables             = doc.css('h2').map(&:text).zip(doc.css('table'))
      beers, breweries   = nil
      tables.each do |(heading, table)|
        case heading
        when 'brewers'
          @breweries = process_breweries_table(table)
        when 'beers'
          @beers = process_beers_table(table)
        end
      end

      # RateBeer is inconsistent with searching for IPAs. If IPA is in the name
      # of the beer, replace IPA with India Pale Ale, and add the additional
      # results to these results.
      if query.downcase.include?(' ipa')
        alt_query = query.downcase.gsub(' ipa', ' india pale ale')
        extra_beers = self.class.new(alt_query).run_search.beers
        @beers = ((@beers || []) + (extra_beers || [])).uniq
      end
      self
    end

    alias retrieve_details run_search

    private
    
    def doc
      @doc ||= post_request(URI.join(BASE_URL, SEARCH_URL), post_params)
    end

    def scrape_beers
      unless instance_variable_defined?('@beers')
        run_search
        @beers = @beers && @beers.sort_by(&:id)
      end
      @beers
    end

    def scrape_breweries
      unless instance_variable_defined?('@breweries')
        run_search
        @breweries = @breweries.sort_by(&:id)
      end
      @breweries
    end

    # Generate parameters to use in POST request.
    #
    def post_params
      { 'BeerName' => @query }
    end

    # Process breweries table returned in search.
    #
    # The breweries table (if returned) consists of a series of rows each
    # containing two cells: the first is the name (and hyperlink) to the
    # brewery; and the second is the full location of the brewery.
    #
    # @param [Nokogiri::XML::Element] table An HTML table containing breweries
    #   information
    # @return [Hash{Symbol, String}] Brewery data, including name, location,
    #   url and ID
    #
    def process_breweries_table(table)
      table.css('tr').map do |row|
        result = [:id, :name, :location, :url].zip([nil]).to_h
        result[:name], result[:location] = row.element_children.map do |x|
          fix_characters(x.text)
        end
        result[:url] = row.at_css('a')['href']
        result[:id]  = result[:url].split('/').last.to_i
        Brewery.new(result[:id], name: result[:name])
      end
    end

    # Process beers table returned in search.
    #
    # The beers table (if returned) consists of a series of rows each of which
    # contains five cells: the first is the name (and hyperlink) to the beer;
    # the second and third relate to features of the RateBeer.com site, and are
    # ignored; the fourth provides the rating of the beer (if any); and the
    # fifth contains the number of ratings submitted for this beer.
    #
    # The first row in the table contains headings, and is disregarded.
    #
    # @param [Nokogiri::XML::Element] table An HTML table containing beers
    #   information
    # @return [Hash{Symbol, String}] Beer data, including name, score, rating,
    #   url and ID
    #
    def process_beers_table(table)
      beers = []
      threads = []
      mutex = Mutex.new
      table.css('tr').drop(1).map do |r|
        threads << Thread.new do
          beer = process_beer_row(r)
          mutex.synchronize { beers << beer }
        end
      end
      threads.each(&:join)
      beers
    end

    # Processes one row from a beer table.
    def process_beer_row(row)
      result = [:id, :name, :score, :ratings, :url].zip([nil]).to_h
      content = row.element_children.map { |x| fix_characters(x.text) }
      result[:name] = content.first
      result[:score], result[:ratings] = content.values_at(3, 4)
                                                .map do |n|
        n.nil? || n.empty? ? nil : n.to_i
      end
      result[:url] = row.at_css('a')['href']
      result[:id]  = result[:url].split('/').last.to_i
      b = Beer.new(result[:id], name: result[:name])
      b.brewery.name if @scrape_beer_brewers
      b
    end

    # Amend search query string for better results
    #
    # RateBeer is a little finicky about finding search results. It does not
    # provide results on abbreviations, and a passed query including special
    # characters will return no hits. Often searching using a generic term such
    # as Co, Brewers, Brewery, etc. will not return any results. This method
    # strips out such generic terms from a query.
    #
    # This method attempts to deal with these issues.
    #
    # @param [String] query Raw query parameter
    # @return [String] Query parameter amended to improve results
    #
    def fix_query_param(query)
      query = strip_generic_terms(query)
      query = substitute_known_terms(query)
      I18n.transliterate(query)
    end

    # Strip defined generic terms from query.
    #
    # This method removes all generic terms which may refer to a brewery, but
    # which may not appear in the brewery's proper name, e.g. brewers.
    #
    # @param [String] query Raw query parameter
    # @return [String] Query parameter with generics stripped out
    #
    def strip_generic_terms(query)
      generic_words = ["Brew",
                       "Brewers", 
                       "Brewery",
                       "Brewing",
                       "Brewhouse",
                       "Company",
                       "Co\.?",
                       "Inc\.?",
                       "Ltd\.?",
                       "Limited"]
      generic_words.map! { |w| /(^| )#{w}( |$)/i }
      generic_words.each { |w| query.gsub!(w, " ") }
      query.strip
    end

    # Substitute known problematic terms in query.
    #
    # This method will replace terms which are known to cause problems in the
    # search with different terms which do not cause the same problem.
    #
    # @param [String] query Raw query parameter
    # @return [String] Query parameter with terms substituted
    #
    def substitute_known_terms(query)
      # List of problem terms - key can be a string or regexp
      problem_terms = { "six°north" => "Six Degrees North",
                        /[\/:]/     => " " }
      problem_terms.each { |term, substitute| query.gsub!(term, substitute) }
      query.strip
    end 

    # Clear cached search data.
    #
    def clear_cached_data
      ["@beers", "@breweries"].each { |v| remove_instance_variable(v) if instance_variable_defined?(v) }
    end
  end
end
