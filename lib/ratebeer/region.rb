require_relative 'location'

module RateBeer
  class Region < Location
    def initialize(id, name=nil)
      super(id, :region, name)
    end
  end
end
