require 'net/http'
require 'nokogiri'
require 'open-uri'

module RateBeer

  # The Scraping module contains a series of methods to assist with scraping
  # pages from RateBeer.com, and dealing with the results.
  module Scraping

    class PageNotFoundError < StandardError; end

    def pagination?(doc)
      !page_count(doc).nil?
    end

    def page_count(doc)
      doc.at_css('.pagination') && doc.at_css('.pagination')
                                      .css('b')
                                      .map(&:text)
                                      .map(&:to_i)
                                      .max
    end

    # Create Nokogiri doc from url.
    #
    def noko_doc(url)
      begin
        Nokogiri::HTML(open(url).read)
      rescue OpenURI::HTTPError => msg
        raise PageNotFoundError.new("Page not found - #{url}")
      end
    end

    # Emulate &nbsp; character for stripping, substitution, etc.
    #
    def nbsp
      Nokogiri::HTML("&nbsp;").text
    end

    # Convert text keys to symbols
    #
    def symbolize_text(text)
      text.downcase.gsub(' ', '_').gsub('.', '').to_sym
    end
    
    # Fix characters in string scraped from website.
    #
    # This method substitutes problematic characters found in
    # strings scraped from RateBeer.com
    #
    def fix_characters(string)
      characters = { nbsp     => " ",
                     "\u0093" => "ž",
                     "\u0092" => "'",
                     "\u0096" => "–" }
      characters.each { |c, r| string.gsub!(c, r) }
      string.strip
    end 

    # Make POST request to RateBeer form. Return a Nokogiri doc.
    #
    def post_request(url, params)
      res = Net::HTTP.post_form(url, params)
      Nokogiri::HTML(res.body)
    end
  end
end
