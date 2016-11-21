require "test_helper"

class DocsContractOverviewTest < Minitest::Spec
  Song = Struct.new(:length, :title)

  #:overv-reform
  # app/concepts/comment/create.rb
  class Create < Trailblazer::Operation
    #~bla
    extend Contract::DSL

    contract do
      property :title
      #~contractonly
      property :length

      validates :title,  presence: true
      validates :length, numericality: true
      #~contractonly end
    end
    #~contractonly

    #~bla end
    self.| Model[Song, :create]
    self.| Contract[]
    self.| Contract::Validate[]
    self.| Persist[method: :sync]
    #~contractonly end
  end
  #:overv-reform end

  puts Create["pipetree"].inspect(style: :rows)

=begin
  #:overv-reform-pipe
   0 =======================>>operation.new
   1 ==========================&model.build
   2 =======================>contract.build
   3 ==============&validate.params.extract
   4 ====================&contract.validate
   5 =========================&persist.save
  #:overv-reform-pipe end
=end

  it do
    assert Create["contract.default.class"] < Reform::Form
  end
end

class DocsContractNameTest < Minitest::Spec
  Song = Struct.new(:length, :title)

  #:contract-name
  # app/concepts/comment/update.rb
  class Update < Trailblazer::Operation
    #~contract
    extend Contract::DSL

    contract :params do
      property :id
      validates :id,  presence: true
    end
    #~contract end
    #~pipe
    self.| Model[Song, :create]
    self.| Contract[name: "params"]
    self.| Contract::Validate[name: "params"]
    #~pipe end
  end
  #:contract-name end
end

class DocsContractReferenceTest < Minitest::Spec
  MyContract = Class.new
  #:contract-ref
  # app/concepts/comment/update.rb
  class Update < Trailblazer::Operation
    #~contract
    extend Contract::DSL
    contract :user, MyContract
  end
  #:contract-ref end
end

#---
# contract MyContract
class DocsContractExplicitTest < Minitest::Spec
  Song = Struct.new(:length, :title)

  #:reform-inline
  class MyContract < Reform::Form
    property :title
    property :length

    validates :title,  presence: true
    validates :length, numericality: true
  end
  #:reform-inline end

  #:reform-inline-op
  # app/concepts/comment/create.rb
  class Create < Trailblazer::Operation
    extend Contract::DSL

    contract MyContract

    self.| Model[Song, :create]
    self.| Contract[]
    self.| Contract::Validate[]
    self.| Persist[method: :sync]
  end
  #:reform-inline-op end
end

#---
#- Validate[key: :song]
class DocsContractKeyTest < Minitest::Spec
  Song = Struct.new(:id, :title)
  #:key
  class Create < Trailblazer::Operation
    extend Contract::DSL

    contract do
      property :title
    end

    self.| Model[Song, :create]
    self.| Contract[]
    self.| Contract::Validate[key: "song"]
    self.| Persist[method: :sync]
  end
  #:key end

  it { Create.({}).inspect("model").must_equal %{<Result:false [#<struct DocsContractKeyTest::Song id=nil, title=nil>] >} }
  it { Create.({"song" => { title: "SVG" }}).inspect("model").must_equal %{<Result:true [#<struct DocsContractKeyTest::Song id=nil, title="SVG">] >} }
end

#- Validate with manual key extraction
class DocsContractSeparateKeyTest < Minitest::Spec
  Song = Struct.new(:id, :title)
  #:key-extr
  class Create < Trailblazer::Operation
    extend Contract::DSL

    contract do
      property :title
    end

    def type
      "evergreen" # this is how you could do polymorphic lookups.
    end

    self.| Model[Song, :create]
    self.| Contract[]
    self.& :extract_params!
    self.| Contract::Validate[skip_extract: true]
    self.| Persist[method: :sync]

    def extract_params!(options)
      options["params.validate"] = options["params"][type]
    end
  end
  #:key-extr end

  it { Create.({ }).inspect("model").must_equal %{<Result:false [#<struct DocsContractSeparateKeyTest::Song id=nil, title=nil>] >} }
  it { Create.({"evergreen" => { title: "SVG" }}).inspect("model").must_equal %{<Result:true [#<struct DocsContractSeparateKeyTest::Song id=nil, title="SVG">] >} }
end

#---
#- Contract[ constant: XXX ]
class ContractConstantTest < Minitest::Spec
  Song = Struct.new(:id, :title)
  #:constant
  class Create < Trailblazer::Operation
    class MyContract < Reform::Form
      property :title
      validates :title, length: 2..33
    end

    self.| Model[Song, :create]
    self.| Contract[constant: MyContract]
    self.| Contract::Validate[]
    self.| Persist[method: :sync]
  end
  #:constant end

  it { Create.({ title: "A" }).inspect("model").must_equal %{<Result:false [#<struct ContractConstantTest::Song id=nil, title=nil>] >} }
  it { Create.({ title: "Anthony's Song" }).inspect("model").must_equal %{<Result:true [#<struct ContractConstantTest::Song id=nil, title="Anthony's Song">] >} }
end

#- Contract[ constant: XXX, name: AAA ]
class ContractNamedConstantTest < Minitest::Spec
  Song = Struct.new(:id, :title)
  #:constant-name
  class Create < Trailblazer::Operation
    class MyContract < Reform::Form
      property :title
      validates :title, length: 2..33
    end

    self.| Model[Song, :create]
    self.| Contract[constant: MyContract, name: "form"]
    self.| Contract::Validate[name: "form"]
    self.| Persist[method: :sync, name: "contract.form"]
  end
  #:constant-name end

  it { Create.({ title: "A" }).inspect("model").must_equal %{<Result:false [#<struct ContractNamedConstantTest::Song id=nil, title=nil>] >} }
  it { Create.({ title: "Anthony's Song" }).inspect("model").must_equal %{<Result:true [#<struct ContractNamedConstantTest::Song id=nil, title="Anthony's Song">] >} }
end




class DryValidationContractTest < Minitest::Spec
  Song = Struct.new(:id, :title)
  #---
  # DRY-validation params validation before op,
  # plus main contract.
  #- result.path
  #:dry-schema
  require "dry/validation"
  class Create < Trailblazer::Operation
    extend Contract::DSL

    # contract to verify params formally.
    contract "params", (Dry::Validation.Schema do
      required(:id).filled
    end)
    #~form
    # domain validations.
    contract "form" do
      property :title
      validates :title, length: 1..3
    end
    #~form end

    self.| Contract::Validate[name: "params"]
    #~form
    self.| Model[Song, :create]                              # create the op's main model.
    self.| Contract[name: "form"]                            # create the Reform contract.
    self.| Contract::Validate[name: "form"]                  # validate the Reform contract.
    self.| Persist[method: :sync, name: "contract.form"] # persist the contract's data via the model.
    #~form end
  end
  #:dry-schema end

  it { Create.({}).inspect("model", "result.contract.params").must_equal %{<Result:false [nil, #<Dry::Validation::Result output={} errors={:id=>[\"is missing\"]}>] >} }
  it { Create.({ id: 1 }).inspect("model", "result.contract.params").must_equal %{<Result:false [#<struct DryValidationContractTest::Song id=nil, title=nil>, #<Dry::Validation::Result output={:id=>1} errors={}>] >} }
  # it { Create.({ id: 1, title: "" }).inspect("model", "result.contract.form").must_equal %{<Result:false [#<struct DryValidationContractTest::Song id=nil, title=nil>] >} }
  it { Create.({ id: 1, title: "" }).inspect("model").must_equal %{<Result:false [#<struct DryValidationContractTest::Song id=nil, title=nil>] >} }
  it { Create.({ id: 1, title: "Yo" }).inspect("model").must_equal %{<Result:true [#<struct DryValidationContractTest::Song id=nil, title="Yo">] >} }

  #:dry-schema-first
  require "dry/validation"
  class Delete < Trailblazer::Operation
    extend Contract::DSL

    contract "params", (Dry::Validation.Schema do
      required(:id).filled
    end)

    self.| Contract::Validate[name: "params"], before: "operation.new"
    #~more
    #~more end
  end
  #:dry-schema-first end
end

class DryExplicitSchemaTest < Minitest::Spec
  #:dry-schema-explsch
  # app/concepts/comment/contract/params.rb
  require "dry/validation"
  MySchema = Dry::Validation.Schema do
    required(:id).filled
  end
  #:dry-schema-explsch end

  #:dry-schema-expl
  # app/concepts/comment/delete.rb
  class Delete < Trailblazer::Operation
    extend Contract::DSL
    contract "params", MySchema

    self.| Contract::Validate[name: "params"], before: "operation.new"
  end
  #:dry-schema-expl end
end

class DocContractTest < Minitest::Spec
  Song = Struct.new(:id, :title)

  #---
  # Contract[constant: MyContract]
  #- no-dsl
  # class MyContract < Reform::Form
  #   property :title
  #   validates :title, length: 2..33
  # end

  # class Create < Trailblazer::Operation
  #   self.| Model[Song, :create]
  #   self.| Contract[constant: MyContract]
  #   self.| Contract::Validate[]
  #   #~est
  #   self.| Persist[method: :sync]
  # end

  #-
  # own builder
  class Allocate < Trailblazer::Operation
    extend Contract::DSL

    contract do
      property :title
      property :current_user, virtual: true

      validates :current_user, presence: true
    end

    self.| Model[Song, :create]
    self.| Contract[builder: :default_contract!]
    self.| Contract::Validate[]
    self.| Persist[method: :sync]

    def default_contract!
      self["contract.default.class"].new(self["model"], current_user: self["user.current"])
    end
  end

  it { Allocate.({}).inspect("model").must_equal %{<Result:false [#<struct DocContractTest::Song id=nil, title=nil>] >} }
  it { Allocate.({ title: 1}, "user.current" => Module).inspect("model").must_equal %{<Result:true [#<struct DocContractTest::Song id=nil, title=1>] >} }

  #---
  # with contract block, and inheritance, the old way.
  class Block < Trailblazer::Operation
    extend Contract::DSL
    contract do
      property :title
    end

    self.| Model[Song, :create]
    self.| Contract[]            # resolves to "contract.class.default" and is resolved at runtime.
    self.| Contract::Validate[]
    self.| Persist[method: :sync]
  end

  it { Block.({}).inspect("model").must_equal %{<Result:true [#<struct DocContractTest::Song id=nil, title=nil>] >} }
  it { Block.({ id:1, title: "Fame" }).inspect("model").must_equal %{<Result:true [#<struct DocContractTest::Song id=nil, title="Fame">] >} }

  class Breach < Block
    contract do
      property :id
    end
  end

  it { Breach.({ id:1, title: "Fame" }).inspect("model").must_equal %{<Result:true [#<struct DocContractTest::Song id=1, title="Fame">] >} }

  #-
  # with constant.
  class Break < Block
    class MyContract < Reform::Form
      property :id
    end
    # override the original block as if it's never been there.
    contract MyContract
  end

  it { Break.({ id:1, title: "Fame" }).inspect("model").must_equal %{<Result:true [#<struct DocContractTest::Song id=1, title=nil>] >} }
end




