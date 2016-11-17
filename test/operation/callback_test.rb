require 'test_helper'

# callbacks are tested in Disposable::Callback::Group.
class OperationCallbackTest < MiniTest::Spec
  Song = Struct.new(:name)

  #---
  # with contract and disposable semantics
  class Create < Trailblazer::Operation
    extend Contract::DSL

    contract do
      property :name
    end

    self.| Model[Song, :create]
    self.| Contract[self["contract.default.class"]]
    self.| Contract::Validate[]
    self.| Callback[:default]


    extend Callback::DSL

    callback do
      on_change :notify_me!
      on_change :notify_you!
    end


    # TODO: always dispatch, pass params.

    def dispatched
      self["dispatched"] ||= []
    end

  private
    def notify_me!(*)
      dispatched << :notify_me!
    end

    def notify_you!(*)
      dispatched << :notify_you!
    end
  end


  class Update < Create
    # TODO: allow skipping groups.
    # skip_dispatch :notify_me!

    callback do
      remove! :on_change, :notify_me!
    end
  end

  #---
  #- inheritance
  it { Update["pipetree"].inspect.must_equal %{[>>operation.new,&model.build,>contract.build,&validate.params.extract,&contract.validate,&callback.default]} }


  it "invokes all callbacks" do
    res = Create.({"name"=>"Keep On Running"})
    res["dispatched"].must_equal [:notify_me!, :notify_you!]
  end

  it "does not invoke removed callbacks" do
    res = Update.({"name"=>"Keep On Running"})
    res["dispatched"].must_equal [:notify_you!]
  end
end
