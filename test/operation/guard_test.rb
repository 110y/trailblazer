require "test_helper"
require "trailblazer/operation/guard"

class LegacyGuardTest < Minitest::Spec
  #---
  # with proc, evaluated in operation context.
  class Create < Trailblazer::Operation
    include Policy::Guard
    policy ->(options) { options["params"][:pass] == self["params"][:pass] && options["params"][:pass] }

    # self.| Policy::Guard[ ->(options) { options["params"][:pass] == self["params"][:pass] && options["params"][:pass] } ]

    def process(*); self[:x] = true; end
    puts self["pipetree"].inspect(style: :rows)
  end

  it { Create.(pass: false)[:x].must_equal nil }
  it { Create.(pass: true)[:x].must_equal true }

  #- result object, guard
  it { Create.(pass: true)["result.policy"].success?.must_equal true }
  it { Create.(pass: false)["result.policy"].success?.must_equal false }

  # with Callable, operation passed in.
  class Update < Create
    class MyGuard
      include Uber::Callable
      def call(operation, options); options["params"][:pass] == operation["params"][:pass] && options["params"][:pass] end
    end
    policy MyGuard.new
  end

  it { Update.(pass: false)[:x].must_equal nil }
  it { Update.(pass: true)[:x].must_equal true }
end


# FIXME: what about block passed to ::policy?
