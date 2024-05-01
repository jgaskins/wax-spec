# `Wax::Spec`

Adds spec helpers for apps using [the `wax` shard](https://github.com/jgaskins/wax). This was pulled out to a separate shard so that apps wouldn't have spec-only dependencies in their production apps.

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   development_dependencies:
     wax-spec:
       github: jgaskins/wax-spec
   ```

2. Run `shards install`

## Usage

In your application's spec helpers, load the appropriate helpers provided by `wax-spec`. For example, in your applications' `spec/routes/route_helper.cr`, you would do this:

```crystal
require "../spec_helper" # your app-wide baseline spec helper file
require "wax-spec/route_helper"
```

Then in your specs you can do this:

```crystal
describe RouteUnderTest do
  app = app(RouteUnderTest.new)

  context "GET /" do
    it "returns 200 OK" do
      response = app.get "/"

      response.should have_status :ok
      response.should have_html "Hello"
    end
  end

  context "POST /" do
    it "returns 201 CREATED with the correct params" do
      response = app.post "/", form: {
        # other params ...
        _authenticity_token: app.authenticity_token,
      }

      response.should have_status :created
    end

    it "returns 400 BAD REQUEST without the authenticity token" do
      response = app.post "/", form: {
        # non-authenticity-token params
      }

      response.should have_status :bad_request
    end
  end
end
```

## Contributing

1. Fork it (<https://github.com/jgaskins/wax-spec/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Jamie Gaskins](https://github.com/jgaskins) - creator and maintainer
