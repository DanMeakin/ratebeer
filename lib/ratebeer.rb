Dir[File.expand_path('../ratebeer/*.rb', __FILE__)].each { |f| require f }

# RateBeer.com scraper
#
# Scrapes required information on beers, breweries, ratings, etc. from the
# RateBeer.com beer database.
#
module RateBeer
  # Create new beer instance, using ID and name passed as arguments.
  #
  # @param [Integer, String] id ID# of beer to retrieve
  # @param [String] name Name of the beer to which ID# relates if known
  # @return [RateBeer::Beer] beer with passed ID#
  #
  def beer(id, name = nil)
    Beer::Beer.new(id, name: name)
  end

  # Create new brewery instance, using ID and name passed as arguments.
  #
  # @param [Integer, String] id ID# of brewery to retrieve
  # @param [String] name Name of the brewery to which ID# relates if known
  # @return [RateBeer::Brewery] brewery with passed ID#
  #
  def brewery(id, name = nil)
    Brewery.new(id, name: name)
  end

  # Create new style instance, using ID and name passed as arguments.
  #
  # @param [Integer, String] id ID# of style to retrieve
  # @param [String] name Name of the style to which ID# relates if known
  # @return [RateBeer::Style] style with passed ID#
  #
  def style(id, name = nil)
    Style.new(id, name: name)
  end

  # Search for a particulary beer or brewery.
  #
  # @param [String] query Search parameters to use
  # @return [Hash<Array>] Hash containing Arrays containing RateBeer::Beer and
  #   RateBeer::Brewery instances matching search parameters
  #
  def search(query)
    Search.search(query)
  end

  [:beer, :brewery, :style, :search].each { |f| module_function f }
end
