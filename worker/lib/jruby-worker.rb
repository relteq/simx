require 'java'
require 'yaml'

require 'worker/worker'
require 'worker/run/aurora'

# A wrapper layer around the normal worker class, because we cannot fork.
class JRubyWorker
  def get_scoped_constant str
    str.split("::").inject(Object) {|c,s|c.const_get s}
  end
  
  # As expected by WorkerManager.
  def error msg
    puts "#{self.class} error: #{msg}"
  end
  
  def done
    puts "#{self.class} done."
  end
  
  def run
    worker_spec = YAML.load($stdin.read)

    ## handle term signal by exiting result code 0
  
    run_class = get_scoped_constant(worker_spec["run_class"])
    instance_name = worker_spec["instance_name"]
    count = worker_spec["count"]
    
    $0 = "#{run_class} count=#{count} jruby workers for #{instance_name}"
    
    threads = []
    count.times do
      threads << Thread.new do
        Worker.new(run_class, worker_spec).execute
      end
    end
    
    threads.each do |thread|
      thread.join
    end
    
    done
  
  rescue => ex
    error ex.message
  end
end
