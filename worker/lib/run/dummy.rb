require 'worker/run/base'

module Run
  class Dummy < Base
    # Number of steps to run, with one update per step.
    attr_reader :step_count

    # Delay in seconds between each step.
    attr_reader :step_delay

    # Param hash sent from user via runq. The only params used are
    # with key :step_count and :step_delay.
    attr_reader :param

    def initialize *args
      super

      @step_count = param["step_count"]
      @step_delay = param["step_delay"]
    end

    def work
      @progress = 0

      step_count.times do |i|
        log.debug "Sleeping for #{step_delay} seconds."
        sleep step_delay
        log.debug "Step #{i} in run ##{batch_index} of batch."
        @progress = i/step_count.to_f
        update
      end
      sleep 0.1 # let other thread send its messages before we finish

      @progress = 1
    end

    def cleanup
      # nothing to do
    end

    def results
      "Dummy run done."
    end
  end
end
