class Trailblazer::Operation
  def self.Nested(step, input:nil)
    step = Nested.for(step, input)

    [ step, { name: "Nested(#{step})" } ]
  end

  # WARNING: this is experimental API, but it will end up with something like that.
  module Element
    # DISCUSS: add builders here.
    def initialize(wrapped=nil)
      @wrapped = wrapped
    end

    module Dynamic
      def initialize(wrapped)
        @wrapped = Option::KW.(wrapped)
      end
    end
  end

  module Nested
    # Is executed at runtime and calls the nested operation.
    class Caller
      include Element

      def call(input, options, options_for_nested)
        call_nested(nested(input, options), options_for_nested)
      end

    private
      def call_nested(operation, options)
        operation._call(options)
      end

      def nested(*); @wrapped end

      class Dynamic < Caller
        include Element::Dynamic

        def nested(input, options)
          @wrapped.(input, options)
        end
      end
    end

    class Options
      include Element

      # Per default, only runtime data for nested operation.
      def call(input, options)
        options.to_runtime_data[0]
      end

      class Dynamic
        include Element::Dynamic

        def call(operation, options)
          @wrapped.(operation, options, runtime_data: options.to_runtime_data[0], mutable_data: options.to_mutable_data )
        end
      end
    end

    # Please note that the instance_variable_get are here on purpose since the
    # superinternal API is not entirely decided, yet.
    def self.for(step, input) # DISCUSS: use builders here?
      invoker            = Caller::Dynamic.new(step)
      invoker            = Caller.new(step) if step.is_a?(Class) && step <= Trailblazer::Operation # interestingly, with < we get a weird nil exception. bug in Ruby?

      options_for_nested = Options.new
      options_for_nested = Options::Dynamic.new(input) if input

      # This lambda is the strut added on the track, executed at runtime.
      ->(operation, options) do
        result = invoker.(operation, options, options_for_nested.(operation, options)) # TODO: what about containers?

        result.instance_variable_get(:@data).to_mutable_data.each { |k,v| options[k] = v }
        result.success? # DISCUSS: what if we could simply return the result object here?
      end
    end
  end
end

