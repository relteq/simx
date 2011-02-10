require 'sequel'

module Runq
  DATA_DIR    = "var/data"
  DB_FILE     = File.join(DATA_DIR, "runq.sqlite")
  
  module Database
    # Makes sure that tables exist.
    def self.new(*args)
      if args[-1].kind_of?(Hash)
        log = args[-1].delete(:log)
      end
      
      db = Sequel.sqlite(*args)
      db.extend self
      db.log = log
      db.create_tables
      db
    end
    
    # Not the same as Sequel::Database#loggers -- for application use
    # rather than dumping all queries.
    attr_accessor :log
    
    def transaction(*)
      tries = 0
      begin
        super
      rescue Sequel::DatabaseError => ex
        tries += 1
        case tries
        when 1..5
          if log
            log.warn "#{ex.message.inspect}" +
              " on try ##{tries}: sleeping #{tries} seconds"
          end
          sleep tries
          retry
        else
          raise
        end
      end
    end
    
    def create_tables
      transaction do
        create_workers_table unless table_exists?(:workers)
        create_batches_table unless table_exists?(:batches)
        create_runs_table unless table_exists?(:runs)
      end
    end

    def create_workers_table
      create_table :workers do
        primary_key :id
        
        text        :host   # on which process is running
        integer     :pid    # of worker process
        
        text        :group  # which group allowed to use, nil->no restriction
        text        :user   # which user allowed to use, nil->no restriction
        ## these should be ids of groups and users in redmine
        ## also, should be a n-to-n table of workers/users and workers/groups

        text        :engine # "aurora" or "dummy"
        float       :cost   # unit-less assessment of the cost of this worker
        
        # nil if worker is ready to accept new run
        foreign_key :run_id, :runs, :key => :id, :null => true
        
        ## stats: uptime, cpu avg, etc.
        
        index :run_id
        index :group
        index :user
      end
    end

    def create_batches_table
      create_table :batches do
        primary_key :id
        
        integer     :scenario_id # nil means user provided xml directly
        text        :scenario_xml # full description of scenario
        text        :name
        integer     :n_runs
        text        :mode     # "prediction" or "simulation"
        text        :engine   # "aurora" or "dummy"
        
        ### how do these relate to settings in the xml file?
        float       :b_time   # begin time (in simulation clock)
        float       :duration # of simulation (in simulation clock)
        
        boolean     :control  # enable control defined in scenario
        boolean     :qcontrol # ditto qcontrol
        boolean     :events   # ditto events
        
        time        :start_time # in wall clock time
        float       :execution_time # in wall clock time
        
        integer     :n_complete # number of runs completed

        text        :group    # for selecting workers
        text        :user
        
        ## how will runs vary? (in sim mode, montecarlo)

        index :group
        index :user
      end
    end
    
    def create_runs_table
      create_table :runs do
        primary_key :id
        
        foreign_key :batch_id, :batches, :key => :id, :null => false
        
        # nil means not assigned to a worker yet
        # non-nil means this is the current OR former run of a worker
        foreign_key :worker_id, :workers, :key => :id, :null => true
        
        float       :frac_complete
        constraint  nil, :frac_complete => 0..1
        
        index :worker_id
        index :batch_id
      end
    end
  end
end
