# Logtail Ruby on Rails example project

To help you get started with using Logtail in your Ruby on Rails projects, we have prepared a simple program that showcases the usage of Logtail logger.

## Download and install the example project
You can download the example project from GitHub directly or you can clone it to a select directory. Make sure you are in the projects directory and run the following command:

```bash
bundle install
```

This will install all dependencies listed in the `Gemfile.lock` file.

Then replace `<SOURCE_TOKEN>` and `<INGESTING_HOST>` in `config/application.rb` with your actual source token and ingesting host which you can find by going to [Sources](https://telemetry.betterstack.com/team/0/sources) -> Configure in Better Stack.

```ruby
config.logger = Logtail::Logger.create_default_logger(
  "<YOUR_ACTUAL_SOURCE_TOKEN>",
  ingesting_host: "in.logs.betterstack.com",
)
```

## Run the example project
 
To run the example application, run the following command:

```bash
rails server
```

This will open a local server [127.0.0.1:3000.](http://127.0.0.1:3000/) On the main page, click the "Let's go!" button to generate test logs.

You should see the following output:

```bash
All done!
Log into your Logtail account to check your logs.
```

This will create a total of 6 different logs, each corresponding to a different log level and one with additional structured data. You can review these logs in Logtail.

# Logging

To send logs to Logtail use the `Rails.logger` logger. It provides 5 logging methods for the 5 default log levels. The log levels and their method are:

- **DEBUG** - Send debug messages using the `debug()` method
- **INFO** - Send informative messages about the application progress using the `info()` method
- **WARN** - Report non-critical issues using the `warn()` method
- **ERROR** - Send messages about serious problems using the `error()` method
- **FATAL** - Send messages about fatal events that caused the app to crash using the `fatal()` method

## Logging example

In this example, we will send two logs - **DEBUG** and **INFO**

```ruby
# Send debug logs messages using the debug() method
Rails.logger.debug("Logtail is ready!")

# Send informative messages about interesting events using the info() method
Rails.logger.info("I am using Logtail!")
```

This will create the following output:

```json
{
    "dt": "2021-03-29T11:24:54.788Z",
    "level": "debug",
    "message": "Logtail is ready!",
    "context": {
        "runtime": {
            "thread_id": 123,
            "file": "main.rb",
            "line": 6,
            "frame": null,
            "frame_label": "<main>"
        },
        "system": {
            "hostname": "hostname",
            "pid": 1234
        }
    }
}

{
    "dt": "2021-03-29T11:24:54.788Z",
    "level": "info",
    "message": "I am using Logtail!",
    "context": {
        "runtime": {
            "thread_id": 123,
            "file": "main.rb",
            "line": 6,
            "frame": null,
            "frame_label": "<main>"
        },
        "system": {
            "hostname": "hostname",
            "pid": 1234
        }
    }
}
```

## Log structured data

You can also log additional structured data. This can help you provide additional information when debugging and troubleshooting your application. You can provide this data as the second argument to any logging method.

```ruby
# Send messages about worrying events using the warn() method
# You can also log additional structured data
Rails.logger.warn(
    "log structured data",
    item: {
        url: "https://fictional-store.com/item-123",
        price: 100.00
    }
)
```

This will create the following output:

```json
{
    "dt": "2021-03-29T11:24:54.788Z",
    "level": "warn",
    "message": "log structured data",
    "item": {
        "url": "https://fictional-store.com/item-123",
        "price": 100.00
    },
    "context": {
        "runtime": {
            "thread_id": 123,
            "file": "main.rb",
            "line": 7,            
            "frame": null,
            "frame_label": "<main>"
        },
        "system": {
            "hostname": "hostname",
            "pid": 1234
        }
    }
}
```

## Context

We add information about the current runtime environment and the current process into a `context` field of the logged item by default.

If you want to add custom information to all logged items (e.g., the ID of the current user), you can do so by adding a custom context:

```ruby
# Provide context to the logs
Logtail.with_context(user: { id: 123 }) do
    Rails.logger.info('new subscription')
end
```

This will generate the following JSON output:

```json
{
    "dt": "2021-03-29T11:24:54.788Z",
    "level": "warn",
    "message": "new subscription",
    "context": {
        "runtime": {
            "thread_id": 123456,
            "file": "main.rb",
            "line": 2,            
            "frame": null,
            "frame_label": "<main>"
        },
        "system": {
            "hostname": "hostname",
            "pid": 1234
        },
        "user": {
            "id": 123
        }
    }
}
```

We will automatically add the information about the current user to each log if you're using Ruby on Rails with Devise (or any other Warden-based authentication) or with Clearance.

### Context for every log line of a request

The request and response lines (`Started GET "/" for 127.0.0.1` and `Completed 200 OK in 12.3ms`) are logged by a Rack middleware, before the request reaches your controller. Context set from inside a controller is therefore attached to the logs from the controller action on, but not to these two lines. To attach context to every log line of a request, set it in a Rack middleware instead.

The user context from Devise or Clearance is set this way, by the `Logtail::Integrations::Rack::UserContext` middleware. If you authenticate differently, give it a lambda that finds the user in the Rack environment and returns a hash, or `nil` when nobody is signed in:

```ruby
# config/initializers/logtail.rb
Logtail::Integrations::Rack::UserContext.custom_user_hash = lambda do |rack_env|
  user_id = rack_env["rack.session"]["user_id"]
  user = User.find_by(id: user_id) if user_id
  user && { id: user.id, email: user.email }
end
```

The hash is logged as `context.user` on every log line of the request, including the request and response lines. The lambda runs on every request, so keep it cheap. It can read anything from the Rack environment, for example an API token from `rack_env["HTTP_AUTHORIZATION"]`.

For any other per-request context (a tenant, an API client, a GraphQL operation name), write your own middleware that wraps the request in `Logtail.with_context` and insert it before the middleware that logs the request and response lines:

```ruby
# config/initializers/logtail.rb
class LogtailTenantContext
  def initialize(app)
    @app = app
  end

  def call(env)
    tenant = env["HTTP_X_TENANT"]
    return @app.call(env) unless tenant

    Logtail.with_context(tenant: { name: tenant }) { @app.call(env) }
  end
end

Rails.application.config.middleware.insert_before Logtail::Integrations::Rack::HTTPEvents, LogtailTenantContext
```

Inserting it before `Logtail::Integrations::Rack::HTTPEvents` also places it after your authentication middleware (such as Warden), so the session and the signed-in user are already available in `env`.

### Context from a controller

If the user is only known once your controller runs (for example, you authenticate from a token in a `before_action`), you can still set the context with Rails' `around_action`. It covers the logs from the controller action and everything it calls, but not the request and response lines, which are logged before the action runs. A simple implementation could look like this:

```ruby
class ApplicationController < ActionController::Base # or ActionController::API
  around_action :with_logtail_context

  private

    def with_logtail_context
      if user_signed_in?
        Logtail.with_context(user_context) { yield }
      else
        yield
      end
    end

    def user_context
      Logtail::Contexts::User.new(
        id: current_user.id,
        name: current_user.name,
        email: current_user.email
      )
    end
end
```
