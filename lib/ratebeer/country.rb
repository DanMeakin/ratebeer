require_relative 'location'

module RateBeer
  class Country < Location
    def initialize(id, name: nil)
      super(id, location_type: :country, name: name)
    end
  end
end
