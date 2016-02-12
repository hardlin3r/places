class Place
  include ActiveModel::Model
  attr_accessor :id, :formatted_address, :location, :address_components

  def initialize(hash)
    @id = hash[:_id].to_s if hash[:_id]
    @address_components = hash[:address_components].map { |a| AddressComponent.new(a) } if hash[:address_components]
    @formatted_address = hash[:formatted_address]
    @location = Point.new(hash[:geometry][:geolocation])
  end

  def persisted?
    !@id.nil?
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
    pipeline = [{:$project=> {
                   :_id => 1, :address_components=> 1, :formatted_address => 1, 'geometry.geolocation': 1}}]
    pipeline << {:$unwind => '$address_components'}
    pipeline << {:$sort => sort} if sort
    pipeline << {:$skip=> offset}
    pipeline << {:$limit => limit} if limit > 0
    self.collection.find.aggregate(pipeline)
  end

  def self.get_country_names
    pipeline = []
    pipeline << {:$unwind => '$address_components'}
    pipeline << {:$project => { 'address_components.long_name' => 1, 'address_components.types' => 1 } }
    pipeline << {:$match => {'address_components.types' => 'country'}}
    pipeline << {:$group => { :_id => '$address_components.long_name'}}
    self.collection.find.aggregate(pipeline).to_a.map { |e| e[:_id] }
  end

  def self.find_ids_by_country_code(country_code)
    pipeline = []
    pipeline << {:$match => { 'address_components.types' => 'country', 'address_components.short_name' => country_code}}
    pipeline << {:$project => { :_id => 1}}
    self.collection.find.aggregate(pipeline).to_a.map { |e| e[:_id].to_s }
  end

  def self.create_indexes
    self.collection.indexes.create_one('geometry.geolocation' => Mongo::Index::GEO2DSPHERE)
  end

  def self.remove_indexes
    self.collection.indexes.drop_one('geometry.geolocation_2dsphere')
  end

  def self.near(point, max_meters = 40000000000)
    self.collection.find('geometry.geolocation' => {:$near => {:$geometry => point.to_hash,:$maxDistance => max_meters}})
  end

  def near(max_meters = 40000000000000)
    self.class.to_places(self.class.near(@location, max_meters))
  end

  def photos(skip = 0, limit = 0)
    Photo.find_photos_for_place(@id).skip(skip).limit(limit).to_a.map { |p| Photo.new(p) }
  end
end
