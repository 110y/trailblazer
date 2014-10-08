# make sure #run always returns model

# in test with sidekiq/testing
# Operation.run #=> call perform_one and return [result, model] (model?)

require 'test_helper'
require 'trailblazer/operation'
require 'trailblazer/operation/worker'
require 'sidekiq/testing'


class WorkerTest < MiniTest::Spec
  class Operation < Trailblazer::Operation
    include Worker

    def run(params)
      "I was working hard on #{params.inspect}"
    end
  end

  class NoBackgroundOperation < Operation
    def self.background?
      false
    end
  end

  # test basic worker functionality.
  describe "with sidekiq" do
    before { @res = Operation.run(:title => "Dragonfly") }

    it { @res.kind_of?(String).must_equal true } # for now, we return the job from sidekiq.
    it { Operation.jobs[0]["args"].must_equal([{"title"=>"Dragonfly"}]) }
    it { Operation.perform_one.must_equal "I was working hard on {\"title\"=>\"Dragonfly\"}" }
  end

  it { NoBackgroundOperation.run(:title => "Dragonfly").must_equal "I was working hard on {:title=>\"Dragonfly\"}" }


  # test manual serialisation (to be done with UploadedFile etc automatically).
  class SerializingOperation < Operation
    include Worker

    def self.serializable(params)
      {:wrap => params}
    end

    def deserializable(params)
      params[:wrap]
    end
  end

  describe "with serialization in sidekiq" do
    before { @res = SerializingOperation.run(:title => "Dragonfly") }

    it { @res.kind_of?(String).must_equal true } # for now, we return the job from sidekiq.
    it { SerializingOperation.jobs[0]["args"].must_equal([{"wrap"=>{"title"=>"Dragonfly"}}]) }
    it { SerializingOperation.perform_one.must_equal "I was working hard on {\"title\"=>\"Dragonfly\"}" }
  end
end


class WorkerFileMarshallerTest < MiniTest::Spec
  def uploaded_file(name)
    tmp = Tempfile.new("bla")
    tmp.write File.open("test/fixtures/#{name}").read

    ActionDispatch::Http::UploadedFile.new(
    :tempfile => tmp,
    :filename => name,
    :type     => "image/png")
  end

  class Operation < Trailblazer::Operation
    class Contract < Reform::Form
      property :title
      property :image, file: true

      property :album do
        property :image, file: true
      end
    end

    include Worker
    extend Worker::FileMarshaller # should be ContractFileMarshaller

    def process(params)
      params
    end
  end

  # TODO: no image

  # with image serializes the file for later retrieval.
  it do
    Operation.run(title: "Dragonfly", image: uploaded_file("apotomo.png"), album: {image: uploaded_file("cells.png")})

    args = Operation.jobs[0]["args"].first
    args["title"].must_equal("Dragonfly")
    args["image"]["filename"].must_equal "apotomo.png"
    args["image"]["tempfile_path"].must_match /trailblazer_upload/

    args["album"]["image"]["filename"].must_equal "cells.png"

    # Operation.perform_one.must_equal([true, {"title" => "Dragonfly", "image" => upload}])
  end
end