require "test_helper"
require "trailblazer/operation/policy"

class OpPolicyTest < MiniTest::Spec
  Song = Struct.new(:name)

  class BlaOperation < Trailblazer::Operation
    include Policy

    def model!(*)
      Song.new
    end

    policy do |params|
      model.is_a?(Song) and params[:valid]
    end

    def process(*)
    end
  end

  # valid.
  it do
    op = BlaOperation.(valid: true)

  end

  # invalid.
  it do
    assert_raises Trailblazer::NotAuthorizedError do
      op = BlaOperation.(valid: false)
    end
  end
end


class OpBuilderDenyTest < MiniTest::Spec
  Song = Struct.new(:name)

  class Create < Trailblazer::Operation
    include Deny

    builds do |params|
      deny! unless params[:valid]
    end

    def process(params)
    end
  end

  class Update < Create
    builds -> (params) do
      deny! unless params[:valid]
    end
  end

  # valid.
  it do
    op = Create.(valid: true)
  end

  # invalid.
  it do
    assert_raises Trailblazer::NotAuthorizedError do
      op = Create.(valid: false)
    end
  end
end



class OpPunditPolicyTest < MiniTest::Spec
  Song = Struct.new(:name)
  User = Struct.new(:name)

  class BlaPolicy
    def initialize(user, song)
      @user = user
      @song = song
    end

    def create?
      @user.is_a?(User) and @song.is_a?(Song)
    end
  end

  class BlaOperation < Trailblazer::Operation
    include Policy::Pundit
    policy BlaPolicy, :create?

    def model!(*)
      Song.new
    end

    def process(*)
    end
  end

  # valid.
  it do
    op = BlaOperation.({current_user: User.new})

  end

  # invalid.
  it do
    assert_raises Pundit::NotAuthorizedError do
      op = BlaOperation.({current_user: nil})
    end
  end
end