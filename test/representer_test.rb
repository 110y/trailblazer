require "test_helper"

require "representable/json"

class RepresenterTest < MiniTest::Spec
  Album  = Struct.new(:title, :artist)
  Artist = Struct.new(:name)

  class Create < Trailblazer::Operation
    require "trailblazer/operation/representer"
    include Representer

    contract do
      property :title
      validates :title, presence: true
      property :artist, populate_if_empty: Artist do
        property :name
        validates :name, presence: true
      end
    end


  end

  class Show < Create
    def process(params)
      @model = Album.new("After The War", Artist.new("Gary Moore"))
    end


    def to_json
      # raise self.class.representer_class.inspect
      self.class.build_representer_class.new(@model).to_json
    end
  end

  require "roar/json/hal"
  class HypermediaShow < Show
    representer do
      include Roar::JSON::HAL

      link(:self) { "//album/#{represented.title}" }
    end
  end


  # generic contract -> representer
  it do
    res, op = Show.run({})
    op.to_json.must_equal %{{"title":"After The War","artist":{"name":"Gary Moore"}}}
  end

  # contract -> representer with hypermedia
  it do
    res, op = HypermediaShow.run({})
    op.to_json.must_equal %{{"title":"After The War","artist":{"name":"Gary Moore"},"_links":{"self":{"href":"//album/After The War"}}}}
  end
end