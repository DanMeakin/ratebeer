# frozen_string_literal: true

require_relative '../urls'

module RateBeer
  module Beer
    # Redirects a beer if it is an alias.
    #
    def redirect_if_alias(doc)
      Alias.new(doc).try_redirect
    end

    # The Alias class.
    #
    # RateBeer treats certain beers as aliases of another (e.g. Koenig Ludwig
    # Weissbier - https://www.ratebeer.com/beer/konig-ludwig-weissbier/14945/)
    # and provides a link to the "original" beer. This class is used to handle
    # redirection where a beer is an alias.
    #
    class Alias
      include RateBeer::URLs

      # CSS selector for container with alias information.
      ALIAS_SELECTOR = '.row.columns-container .col-sm-8'.freeze

      # Create an Alias instance.
      #
      # The Alias class deals with handling beers which may be aliases of
      # others, and so requires redirection to the "proper" beer's page.
      #
      # @param [Nokogiri::Doc] document representing a RateBeer.com beer page
      #
      def initialize(doc)
        @doc = doc
      end

      # Redirects this beer to the "proper" beer page if it represents an alias
      # of another beer.
      #
      # This method returns a new doc value if the beer is an alias, or nil if
      # not.
      def try_redirect
        redirect_to_alias if aliased_beer?
      end

      private

      def aliased_beer?
        alias_pattern = /Also known as(.|\n)*Proceed to the aliased beer\.{3}/
        alias_container && alias_container.text =~ alias_pattern
      end

      def redirect_to_alias
        alias_node = alias_container.at_css('a')
        alias_id = alias_node['href'].split('/').last.to_i
        noko_doc(URI.join(BASE_URL, beer_url(alias_id)))
      end

      def alias_container
        @doc.at_css(ALIAS_SELECTOR)
      end
    end
  end
end
