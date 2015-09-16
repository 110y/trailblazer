require "test_helper"
require "trailblazer/operation/crud/external_model"

class ExternalModelTest < MiniTest::Spec
   Song = Struct.new(:title, :id) do
    class << self
      attr_accessor :find_result # TODO: eventually, replace with AR test.
      attr_accessor :all_records

      def find(id)
        find_result.tap do |song|
          song.id = id
        end
      end
    end
  end # FIXME: use from CrudTest.




  class Bla < Trailblazer::Operation
    include CRUD::ExternalModel
    model Song, :update

    def process(params)
    end
  end

  let (:song) { Song.new("Numbers") }

  before do
    Song.find_result = song
  end

  # ::model!
  it do
    Bla.model!(id: 1).must_equal song
    song.id.must_equal 1
  end

  # call style.
  it do
    Bla.(id: 2).model.must_equal song
    song.id.must_equal 2
  end

  # #present.
  it do
    Bla.present({}).model.must_equal song
  end


  class OpWithBuilder < Bla
    class A < self
    end

    builds -> (model, params) do
      return A if model.id == 1 and params[:user] == 2
    end
  end

  describe "::builds args" do
    it do
      OpWithBuilder.(id: 1, user: "different").must_be_instance_of OpWithBuilder
    end

    it do
      OpWithBuilder.(id: 1, user: 2).must_be_instance_of OpWithBuilder::A
    end
  end
end