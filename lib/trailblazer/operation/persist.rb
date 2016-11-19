class Trailblazer::Operation
  module Persist
    extend Stepable

    def self.import!(operation, import, options={})
      save_method   = options[:method] || :save
      contract_name = options[:contract] || "contract.default"

      import.(:&, ->(input, options) { options[contract_name].send(save_method) }, # TODO: test me.
        name: "persist.save")
    end
  end
end
