require 'apiweb/demo_helpers'

get '/demo' do
  @demo_swf = "/demo/Demo.swf"
  @scenario_url = "/demo/US101-test.xml"
  @gmap_key = ENV["GMAP_KEY"]
  haml(:demo)
end

get '/demo/density-feed' do
  if not $data or $data.empty?
    File.open("public/demo/density-trace.yaml") do |f|
      $data = YAML.load(f)
    end
    $prev_dmap_true = nil
  end
  ## this should be per session
  
  ts, dmap_true = $data.shift
  if not $prev_dmap_true
    $prev_dmap_true = dmap_true
  end
  
  dmap_est = {}
  $prev_dmap_true.each do |lid,den|
    if rand < 0.1
      dmap_est[lid] = 0
      # poor man's fault model
    else
      dmap_est[lid] = den * (1 + (rand - 0.5) * 0.1)
      # poor man's gaussian noise
    end
  end

  $prev_dmap_true = dmap_true
  # poor man's delay
  
  # start work on prediction for future use
  request_predicted_density_from_leia(dmap_est, ts, 5*60)
  
  # see if prediction for current time is available yet
  dmap_pred = read_density_from_leia(ts) || {}
  
  result =
    {
      "tmc_clock_time" => ts,
      "points" => {
        '1' => dmap_true,
        '2' => dmap_est,
        '3' => dmap_pred
      }
    }
  
  result.to_json
end

