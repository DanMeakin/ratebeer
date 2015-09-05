require_relative "brewery"
require_relative "style"
require_relative "urls"

module RateBeer
  class Beer
    include RateBeer::Scraping
    include RateBeer::URLs

    attr_reader :id
    attr_reader :review_order
    attr_reader :review_quantity

    # Create RateBeer::Beer instance.
    #
    # Requires the RateBeer ID# for the beer in question.
    #
    # @param [Integer, String] id ID# of beer to retrieve
    # @param [String] name Name of the beer to which ID# relates if known
    #
    def initialize(id, name=nil)
      @id   = id
      @name = name unless name.nil?
    end

    def inspect
      val = "#<RateBeer::Beer ##{@id}"
      val << " - #{@name}" if instance_variable_defined?("@name")
      val << ">"
    end

    def to_s
      inspect
    end

    # Return URL to access the beer details page.
    #
    def url
      @url ||= beer_url(id)
    end
    
    # Return reviews of this beer.
    #
    def reviews
      @reviews ||= retrieve_reviews
    end

    def review_order=(order)
      options = [:most_recent, :top_raters, :highest_score]
      raise "unknown order: #{order}" unless options.include?(order)
      @reviews      = nil
      @review_order = order
    end

    def review_quantity=(quantity)
      @reviews          = nil
      @review_quantity  = quantity
    end

    # Return full beer details in a Hash.
    #
    def full_details
      { id:           id,
        name:         name,
        brewery:      brewery,       
        url:          url,
        style:        style, 
        glassware:    glassware, 
        availability: availability,
        abv:          abv,
        calories:     calories,
        description:  description, 
        retired:      retired,
        rating:       rating }
    end

    [:name, 
     :brewery, 
     :style, 
     :glassware, 
     :availability, 
     :abv, 
     :calories, 
     :description,
     :retired,
     :rating].each do |attr|
      define_method(attr) do
        unless instance_variable_defined?("@#{attr}")
          retrieve_details
        end
        instance_variable_get("@#{attr}")
      end
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

      @name = doc.css("h1[itemprop='itemreviewed']")
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
      @brewery = Brewery.new(@brewery[:id], fix_characters(@brewery[:name]))
      @style = info_tbl.css('td')[1]
                       .css('div')
                       .first
                       .css('a')
                       .select { |a| a['href'] =~ /beerstyles/ }
                       .map { |a| [:id, 
                                   :name].zip([a['href'].split('/')
                                                        .last
                                                        .to_i, a.text]).to_h }.first
      @style = Style.new(@style[:id], fix_characters(@style[:name]))
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

    # Scrape beer reviews.
    #
    # Scrapes reviews attached to beer pages.
    #
    # @param [Symbol] order       The sort order of reviews. :most_recent, 
    #   :top_raters, or :highest_score.
    # @param [Integer] quantity   The number of reviews to retrieve.
    #
    # @return [Array<Hash>] An array of hashes containing review data.
    #
    def retrieve_reviews
      url_suffix = case review_order
                   when :most_recent
                     "1/"
                   when :top_raters
                     "2/"
                   when :highest_score
                     "3/"
                   else
                     "1/"
                   end

      1.upto(((review_quantity || 10) / 10.0).ceil).flat_map do |page|
        url = URI.join(BASE_URL, beer_url(id), url_suffix, "#{page}/")
        doc = noko_doc(url)
        root = doc.css('#container table table')[3]
        # All reviews are contained within the sole cell in the sole row of the 
        # selected table. Each review consists of rating information, details of 
        # the reviewer, and the text of the review itself. 
        #
        # The components are contained within div, small, div tags respectively.
        # We need to scrape these specifically.
        root.css('td')
            .children
            .select { |x| x.name == 'div' || x.name == 'small' }
            .map(&:text)
            .reject { |x| x.empty? || x.include?("googleFillSlot") }
            .each_slice(3).map do |(rating_data, reviewer_data, review)|
              rating_pattern   = /^(?<total>\d+(\.\d+)?).+
                                  AROMA\s(?<aroma>\d+\/10).+
                                  APPEARANCE\s(?<appearance>\d+\/5).+
                                  TASTE\s(?<taste>\d+\/10).+
                                  PALATE\s(?<palate>\d+\/5).+
                                  OVERALL\s(?<overall>\d+\/20)$/x
              reviewer_pattern = /^(?<name>.+)\s\(\d+\)\s-\s?
                                   (?<location>.+)?\s?-\s
                                   (?<date>.+)$/x
              rating   = rating_data.match(rating_pattern)
              reviewer = reviewer_data.gsub(nbsp, ' ').match(reviewer_pattern)
              { reviewer: reviewer[:name],
                location: reviewer[:location].strip,
                date:     Date.parse(reviewer[:date]),
                rating:   { total:      rating[:total].to_f,
                            overall:    Rational(rating[:overall]),
                            aroma:      Rational(rating[:aroma]),
                            appearance: Rational(rating[:appearance]),
                            taste:      Rational(rating[:taste]),
                            palate:     Rational(rating[:palate]) },
                review:   review }
        end
      end.take(review_quantity || 10)
    end

  end
end
