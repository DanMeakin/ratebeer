require_relative 'location'

module RateBeer
  class Country < Location
    def initialize(id, name=nil)
      super(id, :country, name)
    end
  end
end
