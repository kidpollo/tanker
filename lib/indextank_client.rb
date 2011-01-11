require 'net/http'
require 'uri'
require 'rubygems'
require 'json'

module IndexTank

    private

    class RestClient
        def GET(path, params={})
            path = "#{path}?#{to_query(params)}" if params
            request = Net::HTTP::Get.new "#{@uri.path}#{path}"
            authorize request
            return execute(request)
        end

        def PUT(path, body={})
            request = Net::HTTP::Put.new "#{@uri.path}#{path}"
            authorize request
            request.body = body.to_json if body
            return execute(request)
        end

        def DELETE(path, params={})
            path = "#{path}?#{to_query(params)}" if params
            request = Net::HTTP::Delete.new "#{@uri.path}#{path}"
            authorize request
            return execute(request)
        end

        private

        def to_query(params)
            require 'cgi' unless defined?(CGI) && defined?(CGI::escape)
            r = ''
            params.each do |k,v|
                r << "#{CGI.escape(k.to_s)}=#{CGI.escape(v.to_s)}&"
            end
            return r
        end

        def authorize(req)
            req.basic_auth(@uri.user, @uri.password)
        end

        def execute(req)
            res = Net::HTTP.new(@uri.host).start { |http| http.request(req) }
            if res.is_a? Net::HTTPSuccess
                if res.body.nil? or res.body.empty?
                    return res.code, nil
                else
                    begin
                        return res.code, JSON.parse(res.body)
                    rescue
                        raise "Invalid JSON response: #{res.body}"
                    end
                end
            elsif res.is_a? Net::HTTPUnauthorized
                raise SecurityError, "Authorization required"
            elsif res.is_a? Net::HTTPBadRequest
                raise ArgumentError, res.body
            else
                raise HttpCodeException.new(res.code, res.body)
            end
        end

    end

    public

    class ApiClient < RestClient
        def initialize(api_url)
            @uri = URI.parse(api_url)
        end

        def get_index(name)
            require 'cgi' unless defined?(CGI) && defined?(CGI::escape)
            return IndexClient.new("#{@uri}/v1/indexes/#{CGI.escape(name)}")
        end

        def create_index(name)
            index = get_index(name)
            index.create_index()
            return index
        end

        def delete_index(name)
            return get_index(name).delete_index()
        end

        def list_indexes()
            code, indexes = GET "/v1/indexes"
            return indexes.map do |name,metadata| IndexClient.new "#{@uri}/v1/indexes/#{name}", metadata end
        end
    end

    class IndexClient < RestClient
        def initialize(index_url, metadata=nil)
            @uri = URI.parse(index_url)
            @metadata = metadata
        end

        def code
            return metadata['code']
        end

        def running?
            return metadata!['started']
        end

        def creation_time
            return metadata['creation_time']
        end

        def size
            return metadata['size']
        end

        def exists?
            begin
                metadata!
                return true
            rescue HttpCodeException
                if $!.code == "404"
                    return false
                end
                raise
            end
        end

        # the options argument may contain a :variables key
        # with a Hash from variable numbers to their float values
        # this variables can be used in the scoring functions
        # when sorting a search
        def add_document(docid, fields, options={})
            options.merge!( :docid => docid, :fields => fields )
            code, r = PUT "/docs", options
            return r
        end

        def update_variables(docid, variables, options={})
            options.merge!( :docid => docid, :variables => variables )
            code, r = PUT "/docs/variables", options
            return r
        end

        def delete_document(docid, options={})
            options.merge!( :docid => docid )
            code, r = DELETE "/docs", options
            return r
        end

        # the options argument may contain an :index_code definition to override
        # this instance's default index_code
        def promote(docid, query, options={})
            options.merge!( :docid => docid, :query => query )
            code, r = PUT "/promote", options
            return r
        end


        # the options argument may contain an :index_code definition to override
        # this instance's default index_code
        # it can also contain any of the following:
        #   :start => an int with the number of results to skip
        #   :len => an int with the number of results to return
        #   :snippet => a comma separated list of field names for which a snippet
        #               should be returned. (requires an index that supports snippets)
        #   :fetch => a comma separated list of field names for which its content
        #             should be returned. (requires an index that supports storage)
        #   :function => an int with the index of the scoring function to be used
        #                for this query
        def search(query, options={})
            options = { :start => 0, :len => 10 }.merge(options)
            options.merge!( :q => query )
            begin
                code, r = GET "/search", options
                return r
            rescue HttpCodeException
                raise
            end
        end

        def add_function(function_index, definition, options={})
            options.merge!( :definition => definition )
            code, r = PUT "/functions/#{function_index}", options
            return r
        end

        def del_function(function_index, options={})
            code, r = DELETE "/functions/#{function_index}", options
            return r
        end

        def list_functions(options={})
            code, r = GET "/functions"
            return r
        end

        def create_index()
            begin
                code, r = PUT ""
                raise IndexAlreadyExists if code == "204"
                return r
            rescue HttpCodeException
                if $!.code == "409"
                    puts $!.code
                    raise TooManyIndexes
                end
                raise
            end
        end

        def delete_index()
            code, r = DELETE ""
            return r
        end

        def metadata
            metadata! if @metadata.nil?
            return @metadata
        end

        def metadata!
            code, @metadata = GET ""
            return @metadata
        end

    end

    class IndexAlreadyExists < StandardError
    end
    class TooManyIndexes < StandardError
    end

    class HttpCodeException < StandardError
        def initialize(code, message)
            @code = code
            @message = message
            super("#{code}: #{message}")
        end

        attr_accessor :code
        attr_accessor :message
    end

    class HerokuClient < ApiClient
        def initialize()
            super(ENV['HEROKUTANK_API_URL'])
        end
    end


end

