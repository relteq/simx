module Runq
  class << self
    def add_redmine_callbacks run_id, engine, param
      log.debug "Add redmine callbacks run=#{run_id}, engine=#{engine}"
      run = database[:runs].filter(:id => run_id)
      if engine == 'simulator' && param[:redmine_simulation_batch_id]
        run.update :update_callback => 'update_simulation_callback',
                   :finish_callback => 'finish_simulation_callback'
      elsif engine == 'report generator' && 
            param[:redmine_batch_report_id]
        run.update :update_callback => 'update_report_generator_callback',
                   :finish_callback => 'finish_report_generator_callback'
      end
      log.debug "run update_callback =#{run.first[:update_callback]}"
      log.debug "run finish_callback =#{run.first[:finish_callback]}"
    end

  	def finish_simulation_callback args
	    batch_param = args[:batch_param] or raise "batch param not present"
	    n_complete = args[:n_complete] or raise "n_complete not present"
	    n_runs = args[:n_runs] or raise "n_runs not present"
	    req = args[:req] or raise "req not present"

      simulation_batch_id = batch_param[:redmine_simulation_batch_id]
      frontend_batch = apiweb_db[:simulation_batches].
      					 where(:id => simulation_batch_id)

      if frontend_batch.count > 0
        percent = n_complete.to_f/n_runs.to_f
        log.debug "Changing percent complete of batch" + 
        		  "#{simulation_batch_id} to #{percent}"

        frontend_batch.update( :percent_complete => percent )

        if req.data['ok']
          frontend_batch.update(:succeeded => true)
          if req.data['output_urls']
            req.data['output_urls'].each do |key|
              apiweb_db[:output_files] << {
                :simulation_batch_id => simulation_batch_id,
                :s3_bucket => req.data['bucket'],
                :key => key,
                :created_at => Time.now,
                :updated_at => Time.now
              }
            end
          end
        else
          frontend_batch.update( :succeeded => false, 
                                 :failure_message => req.data['error'] )
        end
      end
  	end

  	def finish_report_generator_callback args
	    batch_param = args[:batch_param] or raise "batch param not present"
      req = args[:req] or raise "req not present"

      frontend_report = apiweb_db[:simulation_batch_reports].
                        where(:id => batch_param[:redmine_batch_report_id])
      if frontend_report.count > 0
        frontend_report.update(:percent_complete => 1)
        if req.data['ok']
          frontend_report.update(:succeeded => true, 
                                 :s3_bucket => req.data['bucket'])
          batch_param['output_types'].each_with_index do |type,index|
            if frontend_report.count > 0
              log.info "Setting report export S3 key for #{type} in Redmine database"
              ext = ext_for_mime_type(type)
              field = case ext
                when "xml" then :xml_key 
                when "pdf" then :pdf_key
                when "xls" then :xls_key
                when "ppt" then :ppt_key
                else begin 
                  log.warn "Unrecognized extension #{ext} in report generator"
                  break
                end
              end
              frontend_report.update(field => req.data['output_urls'][index])
            end
          end
        else
          frontend_report.update( :succeeded => false,
                                  :failure_message => req.data['error'] )
        end
      end
  	end

  	def update_simulation_callback args
      batch_param = args[:batch_param] or raise "batch param not present"
      run = args[:run] or raise "run not present"

	    progress = database[:runs].where(:batch_id => run[:batch_id]).
                 avg(:frac_complete)
      
      simulation_batch_id = batch_param[:redmine_simulation_batch_id]
      apiweb_db[:simulation_batches].where(:id => simulation_batch_id).
        update(:percent_complete => progress)
  	end

  	def update_report_generator_callback args
      batch_param = args[:batch_param] or raise "batch param not present"
      run = args[:run] or raise "run not present"

  	  progress = database[:runs].where(:batch_id => run[:batch_id]).
                     avg(:frac_complete)
      simulation_batch_report_id = batch_param[:redmine_batch_report_id]
      apiweb_db[:simulation_batch_reports].
        where(:id => simulation_batch_report_id).
        update(:percent_complete => progress)
  	end
  end
end
