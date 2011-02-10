require 'socket'

# === MTCP -- Message TCP
#
# Wrapper around TCPSocket and TCPServer that provides a message (datagram)
# abstraction implemented by data stream.
module MTCP

  class Error < StandardError; end
  class MessageLengthError < Error; end
  class MessageUnderflow < Error; end

  # Overrides some methods to give message-oriented behavior to a stream-
  # oriented protocol.
  module Messageable

    MAXLEN  = 10 * 1024 * 1024
    LEN_LEN = [0].pack("N").size

    # Send a message over the socket. The message is like a datagram rather
    # than a stream of data.
    def send_message(message)
      len = message.length
      if len > MAXLEN
        raise MessageLengthError, "MAXLEN exceeded: #{len} > #{MAXLEN}"
      end
      send([len].pack("N"), 0)
      send(message, 0)
    end

    # Receive a message from the socket. Returns +nil+ when there are no
    # more messages (the writer has closed its end of the socket).
    def recv_message
      if (data = recv(LEN_LEN))
        if data.empty?
          nil
        else
          len = data.unpack("N")[0]
          if len > MAXLEN
            raise MessageLengthError, "MAXLEN exceeded: #{len} > #{MAXLEN}"
          end
          begin
            msg = ""
            part = nil
            while msg.length < len and (part = recv(len))
              if part.length == 0 ## what causes this?
                raise MessageUnderflow,
                  "Peer closed socket before finishing message --" +
                  " received #{msg.length} of #{len} bytes:\n" +
                  msg[0..99].unpack("H*")[0] + "..."
              end
              msg << part
            end
            msg.empty? ? nil : msg
          end
        end
      end
    end
  end

  class Socket < TCPSocket
    include Messageable
  end

  class Server < TCPServer
    include Messageable

    if defined?(Errno::EPROTO)
      Eproto = Errno::EPROTO
    else
      class Eproto < Exception; end
    end

    # The same as TCPServer#accept, but returns a MTCP::Socket instead.
    # Also, automatically retries on EPROTO.
    def accept
      Socket.for_fd(sysaccept)
    rescue Eproto
      retry
    end

    def self.open(*args)
      super
    rescue SystemCallError => e
      e.message << " -- was trying #{args.join(":")}"
      raise e
    end

    def self.new(*args)
      super
    rescue SystemCallError => e
      e.message << " -- was trying #{args.join(":")}"
      raise e
    end
  end

end
