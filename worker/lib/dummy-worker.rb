require 'worker/abstract-worker'

class DummyWorker < AbstractWorker
  # Status of current run.
  attr_reader :frac_complete
  
  # Number of steps to run, with one update per step.
  attr_reader :step_count
  
  # Delay in seconds between each step.
  attr_reader :step_delay
  
  def initialize opts
    super
    
    @step_count = opts[:step_count]
    @step_delay = opts[:step_delay]
    
    @frac_complete = nil
  end

  def execute_one_run
    @frac_complete = 0

    step_count = 10
    step_delay = 1.0

    step_count.times do |i|
      sleep step_delay
      log.debug "Step #{i}"
      @frac_complete = i/step_count.to_f
      runq_send_update
      runq_recv do |m| ###
        puts m
      end
    end

    @frac_complete = 1
    runq_send_finished
    runq_recv do |m| ###
      puts m
    end
  end
end
