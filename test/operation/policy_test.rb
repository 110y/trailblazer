require "test_helper"
require "trailblazer/operation/policy"

class PolicyTest < Minitest::Spec
  Song = Struct.new(:id) do
    def self.find(id); new(id) end
  end

  class Auth
    def initialize(*args); @user, @model = *args end
    def only_user?; @user == Module && @model.nil? end
    def user_object?; @user == Object end
    def user_and_model?; @user == Module && @model.class == Song end
    def inspect; "<Auth: user:#{@user.inspect}, model:#{@model.inspect}>" end
  end

  #---
  # Instance-level: Only policy, no model
  class Create < Trailblazer::Operation
    include Pipetree
    include Policy
    policy Auth, :only_user?

    def process(*)
      self["process"] = true
    end

    self["pipetree"] = ::Pipetree[
      Trailblazer::Operation::Build,
      # SetupParams,
      # ModelBuilderBuilder, AssignModel,
      Trailblazer::Operation::Policy::Evaluate,
      Trailblazer::Operation::Policy::Assign,
      Call,
    ]
  end

  # successful.
  it do
    result = Create.({}, "user.current" => Module)
    result["process"].must_equal true
    result["policy.message"].must_equal nil
    # result[:valid].must_equal nil
    result["policy"].inspect.must_equal %{<Auth: user:Module, model:nil>}
  end
  # breach.
  it do
    result = Create.({}, "user.current" => nil)
    result["process"].must_equal nil
    result["policy.message"].must_equal "Not allowed"
  end
  # inject different policy.
  it { Create.({}, "user.current" => Object, "policy.evaluator" => Trailblazer::Operation::Policy::Permission.new(Auth, :user_object?))["process"].must_equal true }
  it { Create.({}, "user.current" => Module, "policy.evaluator" => Trailblazer::Operation::Policy::Permission.new(Auth, :user_object?))["process"].must_equal nil }

  #---
  # inheritance, adding Model
  class Show < Create
    self["pipetree"] = ::Pipetree[
      Trailblazer::Operation::Build,

      Trailblazer::Operation::Model::Build,
      Trailblazer::Operation::Model::Assign,
      # SetupParams,
      Trailblazer::Operation::Policy::Evaluate,
      Trailblazer::Operation::Policy::Assign,
      Call,
    ]

    include Model
    model Song, :create
  end

  # invalid because user AND model.
  it do
    result = Show.({}, "user.current" => Module)
    result["process"].must_equal nil
    result["model"].inspect.must_equal %{#<struct PolicyTest::Song id=nil>}
    # result["policy"].inspect.must_equal %{#<struct PolicyTest::Song id=nil>}
  end

  # valid because new policy.
  it do
    result = Show.({}, "user.current" => Module, "policy.evaluator" => Trailblazer::Operation::Policy::Permission.new(Auth, :user_and_model?))
    result["process"].must_equal true
    result["model"].inspect.must_equal %{#<struct PolicyTest::Song id=nil>}
    result["policy"].inspect.must_equal %{<Auth: user:Module, model:#<struct PolicyTest::Song id=nil>>}
  end

  ##--
  # Policy and Model before Build ("External" or almost Resolver)
  class Edit < Trailblazer::Operation
    include Pipetree
    include Model, Policy
    model Song, :update
    policy Auth, :user_and_model?

    def process(*); self["process"] = true end

    self["pipetree"] = ::Pipetree[
      Trailblazer::Operation::Model::Build,
      Trailblazer::Operation::Model::Assign,
      # SetupParams,
      Trailblazer::Operation::Policy::Evaluate,
      Trailblazer::Operation::Policy::Assign,

      Trailblazer::Operation::Build,
      Call,
    ]
  end

  # successful.
  it do
    result = Edit.({ id: 1 }, "user.current" => Module)
    result["process"].must_equal true
    result["model"].inspect.must_equal %{#<struct PolicyTest::Song id=1>}
    result["policy.message"].must_equal nil
    # result[:valid].must_equal nil
    result["policy"].inspect.must_equal %{<Auth: user:Module, model:#<struct PolicyTest::Song id=1>>}
  end

  # breach.
  it do
    result = Edit.({ id: 4 }, "user.current" => nil)
    result["model"].inspect.must_equal %{#<struct PolicyTest::Song id=4>}
    result["process"].must_equal nil
    result["policy.message"].must_equal "Not allowed"
  end
end
