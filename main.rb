require "redis"
$redis = Redis.new

module ORMModel
  def field(name)
    attr_accessor name
    collection << {:name => name}
  end

  def collection
    @collection ||= []
  end

  def create(options={})
    temp = self.new
    options.each_pair do |key, value|
      temp.send("#{key.to_s}=",value) if temp.respond_to? "#{key}="
    end
    return temp
  end

  def where(options={})
    objects = $redis.smembers(self).map do |id|
      $redis.hgetall("#{self}:#{id}")
    end

    res = []
    objects.each do |obj|
      add = true
      options.each_pair do |k, v|
        add = false if obj[k.to_s] != v.to_s
      end
      res << obj if add
    end

    obj_res = res.map do |obj|
      create(obj)
    end

    return obj_res
  end

  module InstanceMethods
    attr_accessor :id

    def fields
      self.class.collection
    end

    def save
      if @id.nil?
        @id = rand(1000)*rand(1000)
        fields << {:name => :id}
        $redis.sadd(self.class, @id)
      end

      fields.each do |field|
        $redis.hset("#{self.class}:#{@id}", field[:name], self.send(field[:name]))
      end
    end
  end
end

class Post
  extend ORMModel
  include ORMModel::InstanceMethods

  field(:title)
  field(:author)
end

