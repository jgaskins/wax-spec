require "./spec_helper"
require "../src/route_helper"

struct Barebones
  def call(context)
    request = context.request
    response = context.response

    case {request.method, request.path}
    when {"GET", "/"}
      response << "homepage"
    when {"GET", "/posts"}
      response << "posts"
    when {"POST", "/posts"}
      response.status = :created
      response << "create a new post"
    else
      response.status = :not_found
    end
    request.handled!
  end
end

struct MyArmatureRoute
  include Armature::Route
  include Armature::Form::Helper

  def call(context)
    route context do |r, response, session|
      r.root do
        r.post do
          if valid_authenticity_token?(r.form_params, session)
            response.status = :created
          else
            response.status = :bad_request
          end
        end
      end
    end
  end
end

describe "wax-spec/route_helper" do
  context "with a barebones object" do
    app = app(Barebones.new)

    it "gets the root path" do
      response = app.get "/"

      response.should have_status :ok
      response.should have_html "homepage"
    end

    it "gets another path" do
      response = app.get "/posts"

      response.should have_status :ok
      response.should have_html "posts"
    end

    it "allows posts to a non-root path" do
      response = app.post "/posts"

      response.should have_status :created
      response.should have_html "create a new post"
    end

    it "returns not found on an unknown route" do
      response = app.post "/"

      response.should have_status :not_found
    end
  end

  context "with an Armature::Route" do
    app = app(MyArmatureRoute.new)

    it "posts with an authenticity token" do
      response = app.post "/", form: {
        _authenticity_token: app.authenticity_token,
      }

      response.should have_status :created
    end

    it "returns 400 BAD REQUEST without an authenticity_token" do
      response = app.post "/"

      response.should have_status :bad_request
    end
  end
end
