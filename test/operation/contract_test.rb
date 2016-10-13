require "test_helper"
require "trailblazer/operation/contract"

class ContractTest < Minitest::Spec
  class Form
    def initialize(model, options={})
      @inspect = "#{self.class}: #{model} #{options.inspect}"
    end

    def validate
      @inspect
    end
  end

  describe "dependency injection" do
    class Delete < Trailblazer::Operation
      include Contract
    end

    class Follow < Trailblazer::Operation
      include Contract
      def model; end
    end

  # inject contract instance via constructor.
  it { Delete.new({}, contract: "contract/instance").contract.must_equal "contract/instance" }
  it { Follow.new({}, contract_class: Form).contract.class.must_equal Form }
  end


  # contract(model).validate
  class Create < Trailblazer::Operation
    include Contract

    def call(options:false)
      return contract(Object, admin: true).validate if options
      contract(Object).validate
    end
  end

  # inject class, pass in model and options when constructing.
  # contract(model)
  it { Create.({}, contract_class: Form).must_equal "ContractTest::Form: Object {}" }
  # contract(model, options)
  it { Create.({ options: true }, contract_class: Form).must_equal "ContractTest::Form: Object {:admin=>true}" }

  # ::contract Form
  # contract(model).validate
  class Update < Trailblazer::Operation
    include Contract

    self.contract_class = Form

    def call(*)
      contract.validate
    end

    def model
      Object
    end
  end

  # use the class contract.
  it { Update.().must_equal "ContractTest::Form: Object {}" }
  # injected contract overrides class.
  it { Update.({}, contract_class: Injected = Class.new(Form)).must_equal "ContractTest::Injected: Object {}" }
end

class ValidateTest < Minitest::Spec
  class Form
    def initialize(*); end
    def validate(result); result; end
  end

  class Create < Trailblazer::Operation
    include Contract
    contract Form

    def call(params)
      if validate(params[:valid])
        "works!"
      else
        "try again"
      end
    end

    def model
    end
  end

  # validate builds contract using #contract and returns the #validate result.
  it { Create.(valid: false).must_equal "try again" }
  it { Create.(valid: true).must_equal "works!" }
end


# do we want raise! with the result object?

# Model could be a separate object instead of module
# why are all the setup_model methods etc in Op?

