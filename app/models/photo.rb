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
  end

  def persisted?
    not @id.nil?
  end

  def save
    unless persisted?
      gps = EXIFR::JPEG.new(@contents).gps
      @contents.rewind
      @location = Point.new(:lng=> gps.longitude, :lat =>gps.latitude)
      description = {
        :content_type => "image/jpeg",
        :metadata => { :location => @location.to_hash }
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

end
