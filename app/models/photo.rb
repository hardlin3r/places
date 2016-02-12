class Photo
  attr_accessor :id, :location
  attr_writer :contents
  def self.mongo_client
    Mongoid::Clients.default
  end

  def initialize(options = {})
    @id = nil
    @location = nil
    @id = options[:_id].to_s if options[:_id]
    @location = Point.new(options[:metadata][:location]) if options[:metadata] && options[:metadata][:location] && options[:metadata][:location][:coordinates]
    @place = options[:metadata][:place] if options[:metadata] && options[:metadata][:place]
  end

  def persisted?
    not @id.nil?
  end

  def save
   if persisted?
     description = {
       :metadata => { :location => @location.to_hash, :place => @place }
     }
     self.class.mongo_client.database.fs.find({:_id => BSON::ObjectId.from_string(@id)}).update_one(description)
    else
      gps = EXIFR::JPEG.new(@contents).gps
      @contents.rewind
      @location = Point.new(:lng=> gps.longitude, :lat =>gps.latitude)
      description = {
        :content_type => "image/jpeg",
        :metadata => { :location => @location.to_hash, :place => @place }
      }
      grid_file = Mongo::Grid::File.new(@contents.read, description)
      @id = self.class.mongo_client.database.fs.insert_one(grid_file).to_s
    end
  end

  def self.all(skip = 0, limit = 0)
    mongo_client.database.fs.find.skip(skip).limit(limit).map { |p| Photo.new(p) }
  end

  def self.find(id)
    f = mongo_client.database.fs.find(:_id => BSON::ObjectId.from_string(id)).first
    Photo.new(f) if f
  end

  def contents
    f = self.class.mongo_client.database.fs.find_one(:_id => BSON::ObjectId.from_string(@id))
    if f
      buffer = ""
      f.chunks.reduce([]) do |x, chunk|
        buffer << chunk.data.data
      end
      return buffer
    end
  end

  def destroy
    self.class.mongo_client.database.fs.find(:_id => BSON::ObjectId.from_string(@id)).delete_one
  end

  def find_nearest_place_id(max_meters)
    Place.near(@location, max_meters).projection({:$_id => 1}).limit(1).first[:_id]
  end

  def place
    Place.find(@place) unless @place.nil?
  end

  def place=(place)
    case place
    when String then @place = BSON::ObjectId.from_string(place)
    when Place then @place = BSON::ObjectId.from_string(place.id)
    else @place = place
    end
  end

  def self.find_photos_for_place(place)
    case place
    when String then mongo_client.database.fs.find('metadata.place' => BSON::ObjectId.from_string(place))
    when BSON::ObjectId then mongo_client.database.fs.find('metadata.place' => place)
    when Place then mongo_client.database.fs.find('metadata.place' => BSON::ObjectId.from_string(place.id))
    end

  end
end
