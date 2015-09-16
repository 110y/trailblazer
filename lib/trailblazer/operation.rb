require "reform"

module Trailblazer
  class Operation
    require "trailblazer/operation/builder"
    extend Builder # imports ::builder_class and ::build_operation.
    extend Uber::InheritableAttr
    inheritable_attr :contract_class
    self.contract_class = Reform::Form.clone
    self.contract_class.class_eval do
      def self.name # FIXME: don't use ActiveModel::Validations in Reform, it sucks.
        # for whatever reason, validations climb up the inheritance tree and require _every_ class to have a name (4.1).
        "Reform::Form"
      end
    end

    class << self
      def run(params, &block) # Endpoint behaviour
        res, op = build_operation(params).run

        if block_given?
          yield op if res
          return op
        end

        [res, op]
      end

      # Like ::run, but yield block when invalid.
      def reject(*args)
        res, op = run(*args)
        yield op if res == false
        op
      end

      # ::call only returns the Operation instance (or whatever was returned from #validate).
      # This is useful in tests or in irb, e.g. when using Op as a factory and you already know it's valid.
      def call(params)
        build_operation(params, raise_on_invalid: true).run.last
      end

      def [](*args) # TODO: remove in 1.1.
        warn "[Trailblazer] Operation[] is deprecated. Please use Operation.() and have a nice day."
        call(*args)
      end

      # Runs #setup! and returns the form object.
      def present(params)
        build_operation(params).present
      end

      def contract(&block)
        contract_class.class_eval(&block)
      end
    end


    def initialize(params, options={})
      @params           = params
      @options          = options
      @valid            = true

      setup!(params) # assign/find the model
    end

    #   Operation.run(body: "Fabulous!") #=> [true, <Comment body: "Fabulous!">]
    def run
      process(@params)

      [valid?, self]
    end

    def present
      contract!
      self
    end

    attr_reader :model

    def errors
      contract.errors
    end

    def valid?
      @valid
    end

    def contract(*args)
      contract!(*args)
    end

  private
    module Setup
      def setup!(params)
        setup_params!(params)
        build_model!(params)
      end

      def setup_params!(params)
      end

      def build_model!(*args)
        assign_model!(*args) # @model = ..
        setup_model!(*args)
      end

      def assign_model!(*args)
        @model = model!(*args)
      end

      # Implement #model! to find/create your operation model (if required).
      def model!(params)
      end

      # Override to add attributes that can be infered from params.
      def setup_model!(params)
      end
    end
    include Setup

    def validate(params, model=nil, contract_class=nil)
      contract!(model, contract_class)

      if @valid = validate_contract(params)
        yield contract if block_given?
      else
        raise!(contract)
      end

      @valid
    end

    def validate_contract(params)
      contract.validate(params)
    end

    def invalid!(result=self)
      @valid = false
      result
    end

    # When using Op::[], an invalid contract will raise an exception.
    def raise!(contract)
      raise InvalidContract.new(contract.errors.to_s) if @options[:raise_on_invalid]
    end

    # Instantiate the contract, either by using the user's contract passed into #validate
    # or infer the Operation contract.
    def contract_for(model=nil, contract_class=nil)
      model          ||= self.model
      contract_class ||= self.class.contract_class

      contract_class.new(model)
    end

    def contract!(*args)
      @contract ||= contract_for(*args)
    end

    class InvalidContract < RuntimeError
    end
  end
end
