 worker manager

  config
    host: # for deployment
      - [worker,...]
      - [worker,...]
    host:
  
    [
      {
        n_workers: N
        worker: lib/workers/someworker.rb
        options: # for these workers
          runq_host:
          runq_port:
          ...
      }
      {
        n_workers: N
        options: # for these workers
          runq_host
          runq_port
          ...
      }
    ]
  
  runs as daemon
  
  starts each set of workers as child processes
  
  when creating a worker, must specify run_class
  
  set logdev and log level of each worker
  
  if any die, restarts them
  
  manages centralized status, etc.
  
  monitor for out of control process?

  worker: error handling
    each run class must know how to tell if something went wrong
