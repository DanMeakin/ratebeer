require_relative "brewery"
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

    # Return reviews of this beer.
    #
    def reviews(order: :most_recent, limit: 10)
      Review.retrieve(self, order: order, limit: limit)
    end

    private

    # Retrieve details about this beer from the website.
    #
    # This method stores the retrieved details in instance variables
    # of the beer instance.
    #
    def retrieve_details
      doc      = noko_doc(URI.join(BASE_URL, beer_url(id)))
      root     = doc.css('#container table').first
      info_tbl = root.css('table').first 

      @name = doc.css("h1[itemprop='name']")
                 .text
                 .strip
      @name = fix_characters(@name)
      raise PageNotFoundError.new("Beer not found - #{id}") if name.empty?

      # If this beer is an alias, change ID to that of "proper" beer and
      # retrieve details of the proper beer instead.
      if root.css('tr')[1].css('div div').children.first.text == "Also known as "
        alias_node = root.css('tr')[1]
                         .css('div div')
                         .css('a')
                         .first
        alias_name = alias_node.text
        alias_id   = alias_node['href'].split('/').last.to_i
        @id = alias_id
        retrieve_details
        return nil
      end

      @brewery = info_tbl.css('td')[1]
                         .css('div')
                         .first
                         .css('a')
                         .map { |a| [:id, 
                                     :name].zip([a['href'].split('/')
                                                          .last
                                                          .to_i, a.text]).to_h }.first
      @brewery = Brewery.new(@brewery[:id], name: fix_characters(@brewery[:name]))
      @style = info_tbl.css('td')[1]
                       .css('div')
                       .first
                       .css('a')
                       .select { |a| a['href'] =~ /beerstyles/ }
                       .map { |a| [:id, 
                                   :name].zip([a['href'].split('/')
                                                        .last
                                                        .to_i, a.text]).to_h }.first
      @style = Style.new(@style[:id], name: fix_characters(@style[:name]))
      @glassware = info_tbl.css('td')[1]
                          .css('div')[1]
                          .css('a')
                          .map { |a| [:id, 
                                      :name].zip([a['href'].split('GWID=')
                                                           .last
                                                           .to_i, a.text]).to_h }.first
      misc = info_tbl.next_element
                     .first_element_child
                     .children 
                     .map(&:text)
                     .flat_map { |x| x.gsub(nbsp, ' ').strip.split(':') }
                     .map(&:strip)
                     .reject(&:empty?)
                     .each_slice(2)
                     .map { |(k, v)| [symbolize_text(k),
                                      v.to_f.zero? ? v : v.to_f] }
                     .to_h
      @abv      = misc[:abv]
      @calories = misc[:est_calories]
      @rating   = [:overall, 
                   :style].zip(info_tbl.css('div')
                          .select { |d| d['title'] =~ /This figure/ }
                          .map    { |d| d['title'].split(':').first.to_f }).to_h
      @rating.merge!({ ratings:       misc[:ratings], 
                       weighted_avg:  misc[:weighted_avg],
                       mean:          misc[:mean] })
      @availability  = info_tbl.css('td')[1]
                               .css('table')
                               .css('td')
                               .children
                               .children
                               .map(&:text)
                               .reject(&:empty?)
                               .each_slice(2)
                               .to_a
                               .tap { |a| a.last.unshift('distribution') }
                               .map { |(k, v)| [k =~ /bottl/ ?  
                                                :bottling : 
                                                symbolize_text(k), v] }
                               .to_h
      @availability.merge!({ seasonal: misc[:seasonal] })
      @description  = info_tbl.next_element
                              .next_element
                              .children
                              .children
                              .map(&:text)
                              .map(&:strip)
                              .drop(1)
                              .reject(&:empty?)
                              .join("\n")
      @description = fix_characters(@description)
      @retired = !(root.css('span.beertitle2') && 
                   root.css('span.beertitle2').text =~ /RETIRED/).nil?

      nil
    end
  end
end
