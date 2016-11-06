require "declarative"
require "disposable/callback"

# Needs #[], #[]= skill dependency.
module Trailblazer::Operation::Callback
  def self.[](group)
    {
      name: "callback.#{group}",
      operator: :&,
      step: ->(input, options) { input.callback!(group) },
      include: [self],
      skills: {},
    }
  end

  def callback!(name=:default, options=self) # FIXME: test options.
    config  = self["callback.#{name}.class"] || raise #.fetch(name) # TODO: test exception
    group   = config[:group].new(self["contract"])

    options[:context] ||= (config[:context] == :operation ? self : group)
    group.(options)

    invocations[name] = group
  end

  def invocations
    @invocations ||= {}
  end

  module DSL
    def callback(name=:default, constant=nil, &block)
      heritage.record(:callback, name, constant, &block)

      # FIXME: make this nicer. we want to extend same-named callback groups.
      # TODO: allow the same with contract, or better, test it!
      extended = self["callback.#{name}.class"] && self["callback.#{name}.class"]

      path, group_class = Trailblazer::DSL::Build.new.({ prefix: :callback, class: Disposable::Callback::Group, container: self }, name, constant, block) { |extended| extended[:group] }

      self[path] = { group: group_class, context: constant ? nil : :operation }
    end
  end
end
