require "hot_topic"
require "armature/route"
require "armature/form"
require "json"
require "uuid"

def app(app)
  session_handler = WaxSpec::SessionHandler.new(WaxSpec::NotFoundHandler.new(app))
  WaxSpec::SessionClient.new(session_handler, HotTopic.new(session_handler))
end

def have_status(status : HTTP::Status)
  WaxSpec::HaveStatus.new status
end

def have_key(key : String)
  WaxSpec::HaveKey.new(key)
end

def have_html(html : String)
  WaxSpec::HaveHTML.new html
end

def have_html(html : Regex)
  WaxSpec::MatchHTML.new html
end

def redirect_to(path : String | Regex)
  WaxSpec::RedirectTo.new(path)
end

module WaxSpec
  class SessionClient(T) < HTTP::Client
    @session_handler : SessionHandler
    @client : HotTopic::Client(T)
    @host = ""
    @port = -1
    getter cookies : HTTP::Cookies { HTTP::Cookies.new }

    def initialize(@session_handler, @client)
    end

    {% for method in %w(get post put head delete patch options) %}
      # Executes a {{method.id.upcase}} request with form data and returns a `Response`. The "Content-Type" header is set
      # to "application/json".
      #
      # ```
      # require "http/client"
      #
      # client = HTTP::Client.new "www.example.com"
      # response = client.{{method.id}} "/", json: {
      #   foo: "bar",
      # }
      # ```
      def {{method.id}}(path, headers : HTTP::Headers? = nil, *, json) : HTTP::Client::Response
        request = new_request({{method.upcase}}, path, headers, json.to_json)
        request.headers["Content-Type"] = "application/json"
        exec request
      end
    {% end %}

    def session_cookie : String
      @session_handler.session_id
    end

    def authenticity_token : String
      @session_handler.authenticity_token
    end

    def set_csrf_token : self
      @session_handler.set_csrf_token
      self
    end

    def session
      @session_handler.wrapper
    end

    def set_session(**kwargs : String) : self
      kwargs.each do |key, value|
        session_data[key.to_s] = JSON::Any.new(value)
      end
      self
    end

    def session_data
      @session_handler.session_data
    end

    private def exec_internal(request : HTTP::Request)
      unless request.cookies.has_key? "session"
        request.cookies << HTTP::Cookie.new(name: "session", value: session_cookie)
      end
      @client.exec request
    end
  end

  class SessionHandler < Armature::Session::Store
    alias Data = Hash(String, JSON::Any)

    getter session_data : Data { all_data[session_id] }
    getter session_id : String { UUID.random.to_s }
    getter all_data = Hash(String, Data).new { |data, session_id| data[session_id] = Data.new }

    def self.new(app)
      new PassThrough.new(app)
    end

    def initialize(@next : HTTP::Handler)
      @key = session_id
    end

    def authenticity_token
      Armature::Form::Helper.authenticity_token_for wrapper
    end

    def set_csrf_token
      setup_session
      Armature::Form::Helper.generate_authenticity_token! wrapper
    end

    def setup_session
      all_data[session_id] ||= {} of String => JSON::Any
    end

    def call(context)
      session_id = context.request.cookies["session"].value
      session = Session.new(
        data: session_data,
        store: self,
        cookies: context.request.cookies,
      )
      context.session = session

      call_next context
    end

    def wrapper
      Session.new(
        data: session_data,
        store: self,
        cookies: HTTP::Cookies.new,
      )
    end

    class Session < Armature::Session
      def initialize(@data : Data, @store, @cookies)
      end

      def [](key : String)
        @data[key]
      end

      def []=(key : String, value : Hash)
        self[key] = value.transform_values { |value| JSON::Any.new(value) }
      end

      def []=(key : String, value : Hash(String, JSON::Any))
        self[key] = JSON::Any.new(value)
      end

      def []=(key : String, value : JSON::Any::Type)
        self[key] = JSON::Any.new(value)
      end

      def []=(key : String, value : Int)
        self[key] = JSON::Any.new(value.to_i64)
      end

      def []=(key : String, value : JSON::Any)
        @data[key] = value
      end

      def []?(key : String)
        @data[key]?
      end

      def delete(key : String)
        @data.delete key
      end
    end
  end

  # :nodoc:
  class PassThrough
    include HTTP::Handler

    def self.new(route)
      new Wrapper.new(route)
    end

    def initialize(@route : Armature::Route)
    end

    def call(context)
      @route.call context
    end

    # This is a workaround for a bug that seems to happen when we make
    # `PassThrough` generic. I think it has something to do with the combination
    # of a generic type and using `HTTP::Handler` as a type restriction.
    record Wrapper(T), object : T do
      include Armature::Route

      def call(context)
        object.call context
      end
    end
  end

  class NotFoundHandler
    include HTTP::Handler
    include Armature::Route

    def self.new(app)
      new PassThrough.new(app)
    end

    def initialize(@next : HTTP::Handler)
    end

    def call(context)
      route context do |r, response|
        call_next context

        r.miss do
          response.status = :not_found
          response << "Route not found"
        end
      end
    end
  end

  record RedirectTo, path : String | Regex do
    def match(response : HTTP::Client::Response)
      response.status.see_other? && (location = response.headers["location"]?) && match?(location, path)
    end

    def match?(location : String, path : String)
      location == path
    end

    def match?(location : String, path : Regex)
      location.match path
    end

    def failure_message(response : HTTP::Client::Response)
      if !response.status.see_other?
        failure = "its status is #{response.status} (#{response.status_code}) instead of SEE_OTHER (303)"
      elsif !response.headers.has_key? "location"
        failure = "it does not have a Location header"
      else
        failure = "it redirects to #{response.headers["location"].inspect} instead"
      end
      "Response is expected to redirect to #{path.inspect}, but #{failure}"
    end
  end

  record HaveStatus, status : HTTP::Status do
    def match(response : HTTP::Client::Response)
      response.status == status
    end

    def failure_message(response : HTTP::Client::Response)
      "Response is expected to have status #{status} (#{status.code}), but it has #{response.status} (#{response.status.code})"
    end
  end

  record HaveKey, key : String do
    def match(hash)
      hash.has_key? key
    end

    def failure_message(hash)
      "Expected #{hash.inspect} to have key #{key.inspect}"
    end

    def negative_failure_message(hash)
      "Expected #{hash.inspect} NOT to have key #{key.inspect}"
    end
  end

  record HaveHTML, html : String do
    def match(response : HTTP::Client::Response)
      if io = response.body_io?
        raise ArgumentError.new("Can't check a streamed body for HTML content since it reads destructively. Use versions of HTTP::Client methods that don't yield a response block.")
      else
        response.body.includes?(html) || response.body.includes?(HTML.escape(html))
      end
    end

    def failure_message(response : HTTP::Client::Response)
      <<-MESSAGE
      Expected to find #{html.inspect} in this HTML body:
      #{response.body}
      MESSAGE
    end

    def negative_failure_message(response : HTTP::Client::Response)
      <<-MESSAGE
      Expected NOT to find #{html.inspect} in this HTML body:
      #{response.body}
      MESSAGE
    end
  end

  record MatchHTML, matcher : Regex do
    def match(response : HTTP::Client::Response)
      if io = response.body_io?
        raise ArgumentError.new("Can't check a streamed body for HTML content since it reads destructively. Use versions of HTTP::Client methods that don't yield a response block.")
      else
        response.body.match matcher
      end
    end

    def failure_message(response : HTTP::Client::Response)
      <<-MESSAGE
      Expected to match #{matcher.inspect} with this HTML body:
      #{response.body}
      MESSAGE
    end

    def negative_failure_message(response : HTTP::Client::Response)
      <<-MESSAGE
      Expected NOT to match #{matcher.inspect} with this HTML body:
      #{response.body}
      MESSAGE
    end
  end
end
