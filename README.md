# Logtail - Ruby on Rails Logging Made Easy
  
  [![Logtail ruby dashboard](https://user-images.githubusercontent.com/19272921/154085622-59997d5a-3f91-4bc9-a815-3b8ead16d28d.jpeg)](https://betterstack.com/logtail)

[![ISC License](https://img.shields.io/badge/license-ISC-ff69b4.svg)](LICENSE.md)
[![Gem Version](https://badge.fury.io/rb/logtail-ruby.svg)](https://badge.fury.io/rb/logtail-ruby)
[![Build Status](https://github.com/logtail/logtail-ruby-rails/workflows/build/badge.svg)](https://github.com/logtail/logtail-ruby-rails/actions?query=workflow%3Abuild)

Collect logs directly from your Ruby on Rails projects. To start logging Ruby projects explore the [Logtail Ruby library](https://github.com/logtail/logtail-ruby).

[Logtail](https://betterstack.com/logtail) is a hosted service that centralizes all of your logs into one place. Allowing for analysis, correlation and filtering with SQL. Actionable Grafana dashboards and collaboration come built-in. Logtail works with [any language or platform and any data source](https://betterstack.com/docs/logs/). 

### Features
- Simple integration.
- Support for structured logging and events.
- Automatically captures useful context.
- Performant, light weight, with a thoughtful design.

### Supported language versions
- Ruby 2.7.0 or newer
- Rails 6.1.4.2 or newer

# Installation
Install the Logtail Ruby on Rails client library, run the following command:

```bash
bundle add logtail-rails
```

Alternatively, add `gem "logtail-rails"` to your `Gemfile` manually and then run `bundle install`.

Then add following configuration line into your `config/application.rb`:

```ruby
module YourProject
  class Application < Rails::Application
    # ...
    # configuration of your project
    # ...

    config.logger = Logtail::Logger.create_default_logger("<SOURCE_TOKEN>")
  end
end
```

*Don't forget to replace `<SOURCE_TOKEN>` with your actual source token which you can find by going to [Better Stack Logs](https://logs.betterstack.com/dashboard) -> Source -> Edit.*

---

# Example project

To help you get started with using Logtail in your Ruby on Rails projects, we have prepared a simple program that showcases the usage of Logtail logger.

## Download and install the example project

You can download the [example project](https://github.com/logtail/logtail-ruby-rails/tree/main/example-project) from GitHub directly or you can clone it to a select directory. Make sure you are in the projects directory and run the following command:

```bash
bundle install
```

This will install all dependencies listed in the `Gemfile.lock` file.

Then replace `<SOURCE_TOKEN>` in `config/application.rb` with your actual source token which you can find by going to [Better Stack Logs](https://logs.betterstack.com/dashboard) -> Source -> Edit.

```ruby
config.logger = Logtail::Logger.create_default_logger("<YOUR_ACTUAL_SOURCE_TOKEN>")
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

## Explore how example project works
 
Learn how to setup Ruby logging by exploring the workings of the [example project](https://github.com/logtail/logtail-ruby-rails/tree/main/example-project) in detail. 
 
---
 
## Get in touch

Have any questions? Please explore the Better Stack Logs [documentation](https://betterstack.com/docs/logs/) or contact our [support](https://betterstack.com/help).
