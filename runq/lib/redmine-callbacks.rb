module Runq
  class << self
    def add_redmine_callbacks run_id, engine
      log.debug "Add redmine callbacks run=#{run_id}, engine=#{engine}"
      run = database[:runs].filter(:id => run_id)
      if engine == 'simulator'
        run.update :update_callback => 'update_simulation_callback',
                   :finish_callback => 'finish_simulation_callback'
      elsif engine == 'report generator'
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
      frontend_batch = dbweb_db[:simulation_batches].
      					 where(:id => simulation_batch_id)

      if frontend_batch.count > 0
        percent = n_complete.to_f/n_runs.to_f
        log.debug "Changing percent complete of batch" + 
        		  "#{simulation_batch_id} to #{percent}"

        frontend_batch.update( :percent_complete => percent )
        log.debug "Adding output file for run by worker" +
        		  "#{req.worker_id} to output_files"

        if req.data['output_urls']
          req.data['output_urls'].each do |url|
            dbweb_db[:output_files] << {
              :simulation_batch_id => simulation_batch_id,
              :url => url,
              :created_at => Time.now,
              :updated_at => Time.now
            }
          end
        end
      end
  	end

  	def finish_report_generator_callback args
	    batch_param = args[:batch_param] or raise "batch param not present"
      req = args[:req] or raise "req not present"

      frontend_report = dbweb_db[:simulation_batch_reports].
                        where(:id => batch_param[:redmine_batch_report_id])
      if frontend_report.count > 0
        frontend_report.update(:percent_complete => 1)
        batch_param['output_types'].each_with_index do |type,index|
          if frontend_report.count > 0
            log.info "Setting report export URL for #{type} in Redmine database"
            ext = ext_for_mime_type(type)
            field = case ext
              when "xml" then :url 
              when "pdf" then :export_pdf_url
              when "xls" then :export_xls_url
              when "ppt" then :export_ppt_url
              else begin 
                log.warn "Unrecognized extension #{ext} in report generator"
                break
              end
            end
            frontend_report.update(field => req.data['output_urls'][index])
          end
        end
      end
  	end

  	def update_simulation_callback args
      batch_param = args[:batch_param] or raise "batch param not present"
      run = args[:run] or raise "run not present"

	    progress = database[:runs].where(:batch_id => run[:batch_id]).
                 avg(:frac_complete)
      
      simulation_batch_id = batch_param[:redmine_simulation_batch_id]
      dbweb_db[:simulation_batches].where(:id => simulation_batch_id).
        update(:percent_complete => progress)
  	end

  	def update_report_generator_callback args
      batch_param = args[:batch_param] or raise "batch param not present"
      run = args[:run] or raise "run not present"

  	  progress = database[:runs].where(:batch_id => run[:batch_id]).
                     avg(:frac_complete)
      simulation_batch_report_id = batch_param[:redmine_batch_report_id]
      dbweb_db[:simulation_batch_reports].
        where(:id => simulation_batch_report_id).
        update(:percent_complete => progress)
  	end
  end
end