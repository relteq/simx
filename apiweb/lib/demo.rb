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
    $prev = nil
  end

  
  ts, dmap1 = $data.shift
  if not $prev
    $prev = dmap1
  end
  
  dmap2 = {}
  dmap1.each do |lid,den|
    if rand < 0.1
      dmap2[lid] = 0
      # poor man's fault model
    else
      dmap2[lid] = den * (1 + (rand - 0.5) * 0.1)
      # poor man's gaussian noise
    end
  end

  $prev = dmap1
  # poor man's delay
  
  result =
    {
      "tmc_clock_time" => ts,
      "points" => {
        '1' => dmap1,
        '2' => dmap2,
        '3' => {
        }
      }
    }
  
  result.to_json
end

