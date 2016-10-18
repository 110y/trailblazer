require "trailblazer/competences"
# Including this will change the way deserialization in #validate works.
#
# Instead of treating params as a hash and letting the form object deserialize it,
# a representer will be infered from the contract. This representer is then passed as
# deserializer into Form#validate.
#
# TODO: so far, we only support JSON, but it's two lines to change to support any kind of format.
module Trailblazer::Operation::Representer
  def self.included(includer)
    includer.extend DSL

    includer.extend Declarative::Heritage::Inherited
    includer.extend Declarative::Heritage::DSL

    require "trailblazer/operation/competences"
    includer.include Trailblazer::Operation::Competences
  end

  module DSL
    def representer(name=nil, constant=nil, &block)
      heritage.record(:representer, name, constant, &block)

      # FIXME: make this nicer. we want to extend same-named callback groups.
      # TODO: allow the same with contract, or better, test it!
      extended = self["representer.#{name}.class"]
      extended = self["representer.class"] if name.nil?
      puts "@@@@@ #{extended.inspect}"

      path, representer_class = Trailblazer::Competences::Build.new.({ prefix: :representer, class: (extended||representer_base_class) }, name, constant, &block)
      self[path] = representer_class
    end

    # TODO: make engine configurable?
    def representer_base_class
      Class.new(Representable::Decorator) { include Representable::JSON; self }
    end

    def infer_representer_class
      Disposable::Rescheme.from(self["contract.class"],
        include:          [Representable::JSON],
        options_from:     :deserializer, # use :instance etc. in deserializer.
        superclass:       Representable::Decorator,
        definitions_from: lambda { |inline| inline.definitions },
        exclude_options:  [:default, :populator], # TODO: test with populator: in an operation.
        exclude_properties: [:persisted?]
      )
    end
  end

  module InferFromContract
    def to_json(*)
      # TODO: optimize on class-level.
      self["representer.class"] ||= self.class.infer_representer_class
      super
    end
  end

private
  module Rendering
    # Override this if you need to pass options to the rendering.
    #
    #   def to_json(*)
    #     super(include: @params[:include])
    #   end
    def to_json(options={})
      self["representer.class"].new(represented).to_json(options)
    end

    # Override this if you want to render something else, e.g. the contract.
    def represented
      model
    end
  end
  include Rendering


  module Deserializer
    module Hash
      def validate_contract(params)
        # use the inferred representer from the contract for deserialization in #validate.
        contract.validate(params) do |document|
          self.class.representer_class.new(contract).from_hash(document)
        end
      end
    end

    # This looks crazy, but all it does is using a Reform hook in #validate where we can use
    # our own representer for deserialization. After the object graph is set up, Reform will
    # run its validation without even knowing this came from JSON.
    module JSON
      def validate_contract(params)
        contract.validate(params) do |document|
          self.class.representer_class.new(contract).from_json(document)
        end
      end
    end
  end
  include Deserializer::JSON
end
