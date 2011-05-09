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
    puts "Error: #{msg}"
  end
  
  def done
    puts "Done"
  end
  
  def run
    worker_spec = YAML.load($stdin.read)

    ## handle term signal by exiting result code 0
  
    run_class = get_scoped_constant(worker_spec["run_class"])
    $0 = "#{run_class} jruby worker" ## for #{instance_name}"
    Worker.new(run_class, worker_spec).execute
    done
  
  rescue => ex
    error ex.message
  end
end
