module Trailblazer
  class NotAuthorizedError < RuntimeError
  end

  # Adds #evaluate_policy to #setup!, and ::policy.
  module Operation::Policy
    require "trailblazer/operation/policy/guard"

    def self.included(includer)
      includer.extend DSL
    end

    module DSL
      def self.extended(extender)
        extender.inheritable_attr :policy_config
        extender.policy_config = Guard::Permission.new { true } # return true per default.
      end

      def policy(*args, &block)
        self.policy_config = permission_class.new(*args, &block)
      end

      def permission_class
        Permission
      end
    end

    attr_reader :policy

  private
    module Setup
      def setup!(params)
        super
        evaluate_policy(params)
      end
    end
    include Setup


    private
    def evaluate_policy(params)
      puts "evaluate_policy::: @@#{self}@@@ #{params.inspect}, #{model}"
      result, @policy, action = self.class.policy_config.(params[:current_user], model)
      result or raise policy_exception(@policy, action, model)
    end

    def policy_exception(policy, action, model)
      NotAuthorizedError.new(query: action, record: model, policy: policy)
    end

    # Encapsulate building the Policy object and calling the defined query action.
    # This assumes the policy class is "pundit-style", as in Policy.new(user, model).edit?.
    class Permission
      def initialize(policy_class, action)
        @policy_class, @action = policy_class, action
      end

      def call(user, model)
        policy = policy(user, model)
        [policy.send(@action), policy, @action]
      end

      def policy(user, model)
        @policy_class.new(user, model)
      end
    end
  end


  module Operation::Deny
    def self.included(includer)
      includer.extend ClassMethods
    end

    module ClassMethods
      def deny!
        raise NotAuthorizedError
      end
    end
  end
end