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
      rescue Sequel::DatabaseError => e
        tries += 1
        case tries
        when 1..5
          if log
            log.warn "#{e.message.inspect}" +
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
        create_batches_scenarios_table unless table_exists?(:batches_scenarios)
      end
    end

    def create_workers_table
      create_table :workers do
        primary_key :id
        
        text        :host   # on which process is running
        text        :ipaddr # which request came from
        integer     :pid    # of worker process
        
        text        :group  # which group allowed to use, nil->no restriction
        text        :user   # which user allowed to use, nil->no restriction
        ## these should be ids of groups and users in redmine
        ## also, should be a n-to-n table of workers/users and workers/groups

        text        :engine # "aurora", "dummy", etc. May be regex.
        float       :cost   # unit-less assessment of the cost of this worker
        float       :speed  # unit-less assessment of the speed of this worker
        float       :priority
                            # tie-breaker for when multiple workers available
        
        foreign_key :run_id, :runs, :key => :id, :null => true
                            # the run the worker is processing;
                            # nil if worker is ready to accept new run
        
        time        :last_contact
        
        ## stats: uptime, cpu avg, etc.
        
        index :run_id
        index :group
        index :user
        index :engine
      end
    end

    def create_batches_table
      create_table :batches do
        primary_key :id
        
        text        :name
        text        :group    # for selecting workers
        text        :user     # for selecting workers
        text        :engine   # "aurora" or "dummy"

        integer     :n_runs   # number of rows in runs table for this batch
        
        text        :param    # engine-specific YAML string
        
        time        :start_time # in wall clock time
        float       :execution_time # in wall clock time
        integer     :n_complete # number of runs completed

        index :group
        index :user
        index :engine
      end
    end
    
    def create_runs_table
      create_table :runs do
        primary_key :id
        
        foreign_key :batch_id, :batches, :key => :id, :null => false
        
        foreign_key :worker_id, :workers, :key => :id, :null => true
                              # nil means not assigned to a worker yet
                              # non-nil means this is the current OR
                              #  former run of a worker
        
        integer     :batch_index    # in 0..n_runs-1
        
        text        :data     # result data from run; short value or link
        
        float       :frac_complete
        constraint  nil, :frac_complete => 0..1
        
        index :worker_id
        index :batch_id
      end
    end

    def create_batches_scenarios_table
      create_table :batches_scenarios do
        foreign_key   :batch_id,      :batches,      :key => :id
        integer       :scenario_id
        primary_key   :batch_id
      end
    end
  end
end
