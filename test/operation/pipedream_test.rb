require "test_helper"

class PipedreamTest < Minitest::Spec
  Song = Struct.new(:title)

  class Create < Trailblazer::Operation
    class MyContract < Reform::Form
      property :title
    end

    class Auth
      def initialize(user, model); @user, @model = user, model end
      def user_and_model?; @user == Module && @model.class == Song end
    end

    # design principles:
    # * include as less code as possible into the op class.
    # * make the flow super explicit without making it cryptic (only 3 new operators)
    # * avoid including DSL modules in favor of passing those configurations directly to the "step".

    module DSLOperators
      def |(cfg)
        import!(cfg)
      end

      def <(cfg, *args)
        return super unless(cfg.is_a?(Hash))
        import!(cfg.merge(operator: :<))
      end

    # :private:
      def import!(config)
        config[:skills].each { |k,v| self[k] = v } # import skills.
        include *config[:include]                  # include overridable instance logic.
        send(config[:operator], config[:step], name: config[:name], before: "operation.result") # self.> ..
      end
    end
    extend DSLOperators

    self.|         Model[ Song, :create]      # model!)
    self.| Policy::Guard[ ->(options){ options["user.current"] == ::Module } ]
    self.|      Contract[ MyContract]
    self.|        Policy[ Auth, :user_and_model?]
    self.<      Contract[ MyContract]
    # ok Model[Song, :create]      # model!)
    # ok Policy::Guard[ ->(options){ options["user.current"] == ::Module } ]
    # ok Contract[MyContract]
    # fail Contract[MyContract]
    # self.|> "contract"

    # | :bla
    # | ->

  end

  # TODO: test with contract constant (done).
  #       test with inline contract.
  #       test with override contract!.

  it do
    puts Create["pipetree"].inspect(style: :rows)
    result = Create.({}, { "user.current" => Module })

    result["model"].inspect.must_equal %{#<struct PipedreamTest::Song title=nil>}
    result["result.policy"].success?.must_equal true
    result["contract"].class.superclass.must_equal Reform::Form


  end
end
