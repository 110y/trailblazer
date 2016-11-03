require "test_helper"

# self["pipetree"] = ::Pipetree[
#       Trailblazer::Operation::New,
#       # SetupParams,
#       Trailblazer::Operation::Model::Build,
#       Trailblazer::Operation::Model::Assign,
#       Trailblazer::Operation::Call,
#     ]

class PipetreeTest < Minitest::Spec
  Song = Struct.new(:title)

  class Create < Trailblazer::Operation
    include Builder
    include Pipetree # this will add the functions, again, unfortunately. definitely an error source.
  end

  it { Create["pipetree"].inspect.must_equal %{[>>Build,>>New,>>Call,Result::Build,>>New,>>Call,Result::Build]} }

  #---
  # playground
  require "trailblazer/operation/policy"
  require "trailblazer/operation/guard"

  class Edit < Trailblazer::Operation
    include Builder
    include Policy::Guard
    include Contract::Step
    contract do
      property :title
      validates :title, presence: true
    end


    MyValidate = ->(input, options) { res= input.validate(options["params"]) { |f| f.sync } }
    # we can have a separate persist step and wrap in transaction. where do we pass contract, though?
    self.& MyValidate, before: Call #replace: Contract::ValidLegacySwitch
    #
    MyAfterSave = ->(input, options) { input["after_save"] = true }
    self.> MyAfterSave, after: MyValidate

    ValidateFailureLogger = ->(input, options) { input["validate fail"] = true }
    self.< ValidateFailureLogger, after: MyValidate

    self.> ->(input, options) { input.process(options["params"]) }, replace: Call

    include Model

    LogBreach = ->(input, options) { input.log_breach! }

    self.< LogBreach, after: Policy::Evaluate

    model Song
    policy ->(*) { self["user.current"] }

    def log_breach!
      self["breach"] = true
    end

    def process(params)
      self["my.valid"] = true
    end

    self["pipetree"]._insert(Contract::ValidLegacySwitch, {delete: true}, nil, nil)
  end

  puts Edit["pipetree"].inspect(style: :rows)

  it { Edit["pipetree"].inspect.must_equal %{[>>Build,>>New,&Model::Build,&Policy::Evaluate,<LogBreach,>Contract::Build,>>Call,&self,Result::Build]} }

  # valid case.
  it {
    # puts "valid"
  # puts Edit["pipetree"].inspect(style: :rows)
    result = Edit.({ title: "Stupid 7" }, "user.current" => true)
    # puts "success! #{result.inspect}"
    result["my.valid"].must_equal true
    result["breach"].must_equal nil
    result["after_save"].must_equal true
    result["validate fail"].must_equal nil
  }
  # beach! i mean breach!
  it {
    # puts "beach"
  # puts Edit["pipetree"].inspect(style: :rows)
    result = Edit.({})
    # puts "@@@@@ #{result.inspect}"
    result["my.valid"].must_equal nil
    result["breach"].must_equal true
    result["validate fail"].must_equal true
    result["after_save"].must_equal nil
  }
end

# TODO: show the execution path in pipetree
# unified result.contract, result.policy interface
