module RateBeer

  # This module contains URLs or URL patterns for use throughout the Gem.
  #
  module URLs
    BASE_URL   = "http://www.ratebeer.com"
    SEARCH_URL = "/findbeer.asp"

    # Return URL to info page for beer with id
    #
    def beer_url(id)
      "/beer/a/#{id}/"
    end

    # Return URL to page containing reviews for a given beer
    #
    def review_url(beer_id, sort_suffix, page_number)
      "/beer/a/#{beer_id}/#{sort_suffix}/#{page_number}/"
    end

    # Return URL to info page for brewery with id
    #
    def brewery_url(id)
      "/brewers/a/#{id}/"
    end

    # Return URL to info page for country with id
    def country_url(id)
      "/breweries/a/0/#{id}/"
    end

    # Return URL to info page for region with id
    def region_url(id)
      "/breweries/a/#{id}/0/"
    end

    # Return URL to info page for style with id
    def style_url(id)
      "/beerstyles/a/#{id}/"
    end

    # Return URL to beers list page for style with id
    def style_beers_url(id)
      "/ajax/top-beer-by-style.asp?style=#{id}"
    end

    [:beer_url, 
     :brewery_url,
     :country_url, 
     :region_url,
     :style_url,
     :style_beers_url].each { |m| module_function m }
  end
end
