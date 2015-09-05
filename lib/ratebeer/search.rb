require "i18n"
require_relative "scraping"
require_relative "urls"

module RateBeer
  
  # Stop I18N from enforcing locale, to avoid error message
  I18n.enforce_available_locales = false

  # This class provides functionality for searching RateBeer.com for a
  # specific beer or brewery.
  #
  class Search
    include RateBeer::Scraping
    include RateBeer::URLs

    # Search RateBeer for beers, brewers, etc.
    #
    # The search results page contains a series of tables each of which has the
    # "results" class, containing data of matching brewers, beers, and places
    # in that order. Only brewers and beers are extracted.
    #
    # @params [String] query Text to be searched against
    #
    # @return [Hash] Results of the search, broken into breweries and beers,
    #                with the attributes of these results contained therein.
    #
    def search(query)
      query = fix_query_param(query)

      doc           = post_request(URI.join(BASE_URL, SEARCH_URL), 
                                   { 'BeerName' => query })
      headed_tables = doc.css('h2').map(&:text).zip(doc.css('table'))
      beers, breweries = nil
      headed_tables.each do |(heading, table)|
        case heading
        when 'brewers'
          breweries = process_breweries_table(table)
        when 'beers'
          beers = process_beers_table(table)
        end
      end

      # RateBeer is inconsistent with searching for IPAs. If IPA is in the name
      # of the beer, replace IPA with India Pale Ale, and add the additional 
      # results to these results.
      if query.downcase.include?(" ipa")
        extra_beers = search(query.downcase.gsub(" ipa", " india pale ale"))[:beers]
        beers = (beers || []) + extra_beers if extra_beers
      end

      { beers: (beers && beers.uniq), breweries: breweries }

    end

    private

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
        result[:name], result[:location] = row.element_children.map { |x| 
          fix_characters(x.text) 
        }
        result[:url] = row.at_css('a')['href']
        result[:id]  = result[:url].split('/').last.to_i
        Brewery.new(result[:id], result[:name])
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
      table.css('tr').drop(1).map do |row|
        result = [:id, :name, :score, :ratings, :url].zip([nil]).to_h
        content = row.element_children.map { |x| fix_characters(x.text) }
        result[:name]    = content.first
        result[:score], result[:ratings] = content.values_at(3, 4)
                                                  .map { |n| 
          n.nil? || n.empty? ? nil : n.to_i 
        }
        result[:url] = row.at_css('a')['href']
        result[:id]  = result[:url].split('/').last.to_i
        Beer.new(result[:id], result[:name])
      end
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
  end
end
