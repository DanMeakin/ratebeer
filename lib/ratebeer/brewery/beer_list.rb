# frozen_string_literal: true

require_relative '../urls'

module RateBeer
  module Brewery
    # The BeerList class extracts a list of beers for a given brewery.
    class BeerList
      include RateBeer::Scraping
      include RateBeer::URLs

      attr_reader :brewery, :id

      def initialize(brewery)
        @brewery = brewery
        @id = brewery.id
      end

      def beers
        beers_doc = noko_doc(URI.join(BASE_URL, brewery_beers_url(id)))
        rows = beers_doc.css('table#brewer-beer-table tbody tr')
        @beers = rows.map { |row| process_beer_row(row) }.reject(&:nil?)
      end

      private

      # Process a row of data representing one beer brewed by/at a brewery.
      #
      # @param [Nokogiri::XML::Element] row HTML TR row wrapped as a Nokogiri
      #   element
      # @param [String] location the location at which a brewery's beer is brewed
      #   where this location differs from the brewery's regular brewsite/venue
      # @param [String] brewer the client for whom this brewery brewed the beer,
      #   where the brewery is brewing for a different company/brewery
      # @return [RateBeer::Beer] a beer object representing the scraped beer,
      #   containing scraped attributes
      #
      def process_beer_row(row)
        beer = process_beer_name_cell(row.css('td').first)
        beer[:abv] = row.css('td')[1].text.to_f
        beer[:date_added] = Date.strptime(row.css('td')[2].text, '%m/%d/%Y')
        Beer::Beer.new(id, beer.merge(process_rating_info(row)))
      end

      # Processes the cell containing the beer's name and other information.
      #
      # This cell contains information on the beer's name, its style, whether it
      # is retired, and who is was brewed for or by.
      def process_beer_name_cell(node)
        beer_link = node.at_css('strong a')
        name = fix_characters(beer_link.text)
        id = id_from_link(beer_link)
        info = node.at_css('em.real-small')
        brewed_at_for = process_brewed_at_for(node)
        style = process_style_info(node)
        { id:     id,
          name:   name,
          style:  style,
          retired:  info && info.text =~ /retired/ || false }.merge(brewed_at_for)
      end

      # Processes information on who the beer was brewed for or by, or at.
      def process_brewed_at_for(node)
        brewed_at_for_node = node.at_css('div.small em')
        return {} if brewed_at_for_node.nil?
        node_text = brewed_at_for_node.children.first.text
        key = if node_text.include?('Brewed at')
                :brewed_at
              elsif node_text.include?('Brewed by/for')
                :brewed_by_for
              end
        other_brewer_node = brewed_at_for_node.at_css('a')
        { key => Brewery.new(id_from_link(other_brewer_node),
                             name: other_brewer_node.text) }
      end

      # Processes the style information contained within a beer name cell.
      def process_style_info(node)
        style_node = node.css('a').find do |n|
          n.children.any? { |c| c.name == 'span' }
        end
        name = style_node.text
        id = id_from_link(style_node)
        Style.new(id, name: name)
      end

      # Processes rating information from a beer row.
      def process_rating_info(row)
        cell_indices = { avg_rating:      4,
                         style_rating:    5,
                         num_ratings:     6 }
        rating = cell_indices.map do |attr, i|
          val = row.css('td')[i].text.gsub(nbsp, ' ').strip
          conversion = attr == :avg_rating ? :to_f : :to_i
          [attr, val.send(conversion)]
        end
        rating.to_h
      end
    end
  end
end
