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

      private

      def read_capped(response)
        body = response.body.to_s
        raise Errors::Schema, "response exceeded #{MAX_BYTES} bytes" if body.bytesize > MAX_BYTES

        body.dup.force_encoding("UTF-8")
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
