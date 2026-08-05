module Catalog
  module Providers
    # The only place in the application that performs a provider HTTP request.
    #
    # Kept behind a tiny interface (`#get`) so the adapter can be driven by a
    # fake in tests. That is why Stage 2 needs no HTTP client gem and no
    # request-stubbing gem: the seam is the object, not the socket.
    class HttpTransport
      Response = Data.define(:status, :body, :headers) do
        def success? = status == 200
      end

      OPEN_TIMEOUT = 5
      READ_TIMEOUT = 15
      # A metadata page is a few tens of KB. Anything dramatically larger means
      # something is wrong, and we should not buffer it into memory.
      MAX_BYTES = 5_000_000

      def get(url, headers: {})
        uri = URI(url)
        request = Net::HTTP::Get.new(uri)
        headers.each { |key, value| request[key] = value }

        response = client(uri).request(request)
        body = read_capped(response)

        Response.new(
          status: response.code.to_i,
          body: body,
          headers: response.each_header.to_h
        )
      rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNRESET, Errno::ECONNREFUSED,
             EOFError, SocketError, IOError => e
        # Deliberately does not include the URL: it is not secret today, but
        # this message reaches catalog_sync_runs.error_summary and must never
        # become a place where an authenticated URL could leak.
        raise Errors::Transient, "network failure: #{e.class}"
      end

      # Binary fetch that stops mid-download once `max_bytes` is exceeded.
      #
      # `#get` reads the whole body before it can check the size, which is fine
      # for a metadata page but not for media: a hostile or broken upstream
      # could stream gigabytes into memory before the cap was ever consulted.
      # This reads in chunks and abandons the connection as soon as the limit
      # is passed, so memory stays bounded by `max_bytes`.
      #
      # The body is left as binary. Forcing an encoding here would corrupt it.
      def get_binary(url, headers: {}, max_bytes: MAX_BYTES)
        uri = URI(url)
        request = Net::HTTP::Get.new(uri)
        headers.each { |key, value| request[key] = value }

        status = nil
        response_headers = {}
        buffer = +"".b

        client(uri).request(request) do |response|
          status = response.code.to_i
          response_headers = response.each_header.to_h

          if status == 200
            response.read_body do |chunk|
              buffer << chunk
              if buffer.bytesize > max_bytes
                raise Errors::Schema, "response exceeded #{max_bytes} bytes"
              end
            end
          else
            # Error bodies are small and are not returned to the client, but
            # they are still capped rather than trusted.
            buffer << response.body.to_s.byteslice(0, 4096).to_s
          end
        end

        Response.new(status: status, body: buffer, headers: response_headers)
      rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNRESET, Errno::ECONNREFUSED,
             EOFError, SocketError, IOError => e
        raise Errors::Transient, "network failure: #{e.class}"
      end

      private

      def read_capped(response)
        body = response.body.to_s
        raise Errors::Schema, "response exceeded #{MAX_BYTES} bytes" if body.bytesize > MAX_BYTES

        body
      end

      def client(uri)
        Net::HTTP.new(uri.host, uri.port).tap do |http|
          http.use_ssl = uri.scheme == "https"
          http.open_timeout = OPEN_TIMEOUT
          http.read_timeout = READ_TIMEOUT
        end
      end
    end
  end
end
