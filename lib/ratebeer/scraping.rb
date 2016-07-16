require 'net/http'
require 'nokogiri'
require 'open-uri'

module RateBeer

  # The Scraping module contains a series of methods to assist with scraping
  # pages from RateBeer.com, and dealing with the results.
  module Scraping

    class PageNotFoundError < StandardError; end

    attr_reader :id

    # Run method on inclusion in class.
    def self.included(base)
      base.data_keys.each do |attr|
        define_method(attr) do
          unless instance_variable_defined?("@#{attr}")
            retrieve_details
          end
          instance_variable_get("@#{attr}")
        end
      end
    end

    # Create RateBeer::Scraper instance.
    #
    # Requires an ID#, and optionally accepts a name and options parameters.
    #
    # @param [Integer, String] id ID# of the entity which is to be retrieved
    # @param [String] name Name of the entity to which ID# relates if known
    # @param [hash] options Options hash for entity created
    #
    def initialize(id, name: nil, **options)
      @id   = id
      @name = name unless name.nil?
      options.each do |k, v|
        instance_variable_set("@#{k.to_s}", v)
      end
    end

    def inspect
      val = "#<#{self.class} ##{@id}"
      val << " - #{@name}" if instance_variable_defined?("@name")
      val << ">"
    end

    def to_s
      inspect
    end

    def ==(other_entity)
      other_entity.is_a?(self.class) && id == other_entity.id
    end

    def url
      @url ||= if respond_to?("#{demodularized_class_name.downcase}_url", id)
                 send("#{demodularized_class_name.downcase}_url", id)
               end
    end

    # Return full details of the scraped entity in a Hash.
    #
    def full_details
      data = self.class
                 .data_keys
                 .map { |k| [k, send("#{k}")] }
                 .to_h
      { id:   id,
        url:  url }.merge(data)
    end

    # Determine if data is paginated, or not.
    #
    # @param [Nokogiri::Doc] doc Nokogiri document to test for pagination
    # @return [Boolean] true, if paginated, else false
    #
    def pagination?(doc)
      !page_count(doc).nil?
    end

    # Determine the number of pages in a document.
    #
    # @param [Nokogiri::Doc] doc Nokogiri document to test for pagination
    # @return [Integer] Number of pages in the document
    #
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

    module_function :noko_doc

    # Emulate &nbsp; character for stripping, substitution, etc.
    #
    def nbsp
      Nokogiri::HTML("&nbsp;").text
    end

    module_function :nbsp

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
      string = string.encode('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '')
      characters = { nbsp     => " ",
                     "\u0093" => "ž",
                     "\u0092" => "'",
                     "\u0096" => "–",
                     / {2,}/ => " " }
      characters.each { |c, r| string.gsub!(c, r) }
      string.strip
    end 

    # Make POST request to RateBeer form. Return a Nokogiri doc.
    #
    def post_request(url, params)
      res = Net::HTTP.post_form(url, params)
      Nokogiri::HTML(res.body)
    end

    private

    def demodularized_class_name
      self.class.name.split("::").last
    end
  end
end
