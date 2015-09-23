require "test_helper"
require "trailblazer/operation/dispatch"


class DslCallbackTest < MiniTest::Spec
  module SongProcess
    def process(params)
      contract(OpenStruct.new).validate(params)
      dispatch!
    end

    def _invocations
      @_invocations ||= []
    end

    def self.included(includer)
      includer.contract do
        property :title
      end
    end
  end

  describe "inheritance across operations" do
    class Operation < Trailblazer::Operation
      include Dispatch
      include SongProcess

      callback do
        on_change :default!
      end

      class Admin < self
        callback do
          on_change :admin_default!
        end

        callback(:after_save) { on_change :after_save! }

        def admin_default!(*); _invocations << :admin_default!; end
        def after_save!(*);    _invocations << :after_save!; end

        def process(*)
          super
          dispatch!(:after_save)
        end
      end

      def default!(*); _invocations << :default!; end
    end

    it { Operation.({"title"=> "Love-less"})._invocations.must_equal([:default!]) }
    it { Operation::Admin.({"title"=> "Love-less"})._invocations.must_equal([:default!, :admin_default!, :after_save!]) }
  end

  describe "Op.callback" do
    it { Operation.callback(:default).must_equal Operation.callbacks[:default] }
  end

  describe "Op.callback :after_save, AfterSaveCallback" do
    class AfterSaveCallback < Disposable::Callback::Group
      on_change :after_save!
    end

    class OpWithExternalCallback < Trailblazer::Operation
      include Dispatch
      include SongProcess
      callback :after_save, AfterSaveCallback

      def process(params)
        contract(OpenStruct.new).validate(params)
        dispatch!(:after_save)
      end

      def after_save!(*);    _invocations << :after_save!; end
    end

    it { OpWithExternalCallback.("title"=>"Thunder Rising")._invocations.must_equal([:after_save!]) }
  end
end