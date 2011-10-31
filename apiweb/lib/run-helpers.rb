helpers do
  def send_request_and_recv_response req
    reply = nil
    MTCP::Socket.open(RUNQ_HOST, RUNQ_PORT) do |sock|
      sock.send_message req.to_yaml
      reply_str = sock.recv_message
#log.info "reply_str = #{reply_str.inspect}"
      reply = YAML.load(reply_str)
    end

    if reply["status"] == "ok"
      log.info reply["message"]
    else
      log.warn reply["message"]
    end

    return reply
  
  rescue *NETWORK_ERRORS => e
    status 500
    return {
      "status" => "error",
      "message" => e.message,
    }
  end
end

