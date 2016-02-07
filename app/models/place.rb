class Place

  attr_accessor :id, :formatted_address, :location, :address_components

  def initialize(hash)
    @id = hash[:_id].to_s if hash[:_id]
    @address_components = hash[:address_components].map { |a| AddressComponent.new(a) }
    @formatted_address = hash[:formatted_address]
    @location = Point.new(hash[:geometry][:geolocation])
  end

  def self.mongo_client
    Mongoid::Clients.default
  end

  def self.collection
    mongo_client[:places]
  end

  def self.load_all(f)
    string = f.read
    hash = JSON.parse(string)
    collection.insert_many(hash)
  end

  def self.find_by_short_name(string)
    collection.find('address_components.short_name' => string)
  end

  def self.to_places(view)
    arr = []
    view.each do |v|
      arr << Place.new(v)
    end
    arr
  end

  def self.find(id)
    bson_id = BSON::ObjectId.from_string(id)
    result = collection.find({ _id: bson_id }).first
    return result.nil? ? nil : Place.new(result)
  end

  def self.all(offset = 0, limit = 0)
    collection.find().skip(offset).limit(limit).map { |p| Place.new(p) }
  end

  def destroy
    self.class.collection.find(_id: BSON::ObjectId.from_string(@id)).delete_one
  end

  def self.get_address_components(sort = nil, offset = 0, limit = 0)
    #TODO collection.find()
  end
end
