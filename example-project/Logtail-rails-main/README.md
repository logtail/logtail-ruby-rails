# Logtail Rails

Collect logs directly from Ruby on Rails projects.
**Supported language versions:**
Ruby 2.7.0 or newer
Rails 6.1.4.2 or newer

# Installation and setup

You can install Logtail to your Rails projects using the Ruby Bundler.

### Ruby Bundler

If you have Ruby bundler already installed you can skip this step. Run the following command to install the ruby bundler:

```bash
sudo apt install ruby-bundler
```

## Ruby on Rails

To install Logtail to your Ruby on Rails project, run the following command

```bash
bundle add logtail-rails
```

Alternatively, add `gem "logtail-rails"` to your `Gemfile` manually and then run `bundle install`

Then run the following command to create the default config file:

```bash
bundle exec rake logtail:install source_token=YOUR_LOGTAIL_SOURCE_TOKEN
```

Don’t forget to replace `YOUR_LOGTAIL_SOURCE_TOKEN` with your actual source token which you can find in the source settings. This will generate `config/initializers/logtail.rb`.

# Example project

To help you get started and integrate Logtail in your projects, we have prepared an example Rails project. 

## How to run the example project

First, download or clone the repository into the select directory. Make sure you are in the projects directory and run the following command:

```bash
bundle install
```

This will install all dependencies listed in the `Gemfile.lock` file.

Then run the example project by executing the following command:

```bash
rails server
```

This will open a local server [127.0.0.1:3000](http://127.0.0.1:3000). On the main page, click the "Let's go!" button to generate test logs.

You should see the following output:
```
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

In this example, we will send two logs - DEBUG and INFO

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
            "hostname": "hostname"
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
            "hostname": "hostname"
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
            "hostname": "hostname"
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
            "hostname": "hostname"
            "pid": 1234
        },
        "user": {
            "id": 123
        }
    }
}
```

We will automatically add the information about the current user to each log if you're using Ruby on Rails and the Devise gem.

If you're not using Devise or you want to log some additional information for every request your Rails app handles, you can easily implement this using Rails' `around_action` in your application controller. A simple implementation could look like this:

```ruby
class ApplicationController < ActionController::Base
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
