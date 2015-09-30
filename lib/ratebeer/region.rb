require_relative 'location'

module RateBeer
  class Region < Location
    def initialize(id, name: nil)
      super(id, location_type: :region, name: name)
    end
  end
end
