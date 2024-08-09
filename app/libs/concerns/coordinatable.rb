module Coordinatable
  # after_commit :dispatch_signal, on: :save

  def dispatch_signal
    raise ArgumentError, "No `coordinatable_states` in your model!" unless respond_to?(:coordinatable_states)
    coordinatable_states.each do |state, (signal, args)|
      raise ArgumentError, "Signal args must be an array!" unless args.is_a?(Array)
      raise ArgumentError, "No signal for state: #{state}" unless Coordinators::Signals.respond_to?(signal)
      next if state != status.to_s
      next unless previous_changes.key?(:status)

      Coordinators::Signals.public_send(signal, **args)
    end
  end

  # def coordinatable_states
  #   {
  #     release_completed: -> { [:release_completed!, [self]] },
  #   }
  # end
end
