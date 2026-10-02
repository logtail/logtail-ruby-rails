require "spec_helper"

RSpec.describe Logtail::Integrations::ActionView::LogSubscriber do
  let(:time) { Time.utc(2016, 9, 1, 12, 0, 0) }
  let(:io) { StringIO.new }
  let(:logger) do
    logger = Logtail::Logger.new(io)
    logger.level = ::Logger::WARN
    logger
  end

  describe "insert!" do
    around(:each) do |example|
      class ActionViewLogSubscriberController < ActionController::Base
        layout nil

        def index
          render template: "template"
        end

        def method_for_action(action_name)
          action_name
        end
      end

      ::RailsApp.routes.draw do
        get 'action_view_log_subscriber' => 'action_view_log_subscriber#index'
      end

      with_rails_logger(logger) do
        Timecop.freeze(time) { example.run }
      end

      Object.send(:remove_const, :ActionViewLogSubscriberController)
    end

    describe "#render_template" do
      it "should not log if the level is not sufficient" do
        dispatch_rails_request("/action_view_log_subscriber")
        expect(io.string).to eq("")
      end

      context "with an info level" do
        around(:each) do |example|
          old_level = logger.level
          logger.level = ::Logger::INFO
          example.run
          logger.level = old_level
        end

        it "should log a template render event once" do
          dispatch_rails_request("/action_view_log_subscriber")
          lines = clean_lines(io.string.split("\n"))
          expect(lines[2].strip).to match(/Rendered spec\/support\/rails\/templates\/template.html \(\d+\.\d+ms\)/)
          expect(lines[2]).to include("\"template_rendered\":{\"name\":\"spec/support/rails/templates/template.html\"")
        end

        if Rails.respond_to?(:event)
          # What config.log_level = :info does when the app boots. Rails 8.2 reports the rendering
          # events to Rails.event in debug mode only.
          context "with the debug mode of Rails.event turned off" do
            around(:each) do |example|
              debug_mode = Rails.event.debug_mode?
              Rails.event.debug_mode = false
              example.run
              Rails.event.debug_mode = debug_mode
            end

            it "should log a template render event once" do
              dispatch_rails_request("/action_view_log_subscriber")
              lines = clean_lines(io.string.split("\n"))
              expect(lines[2].strip).to match(/Rendered spec\/support\/rails\/templates\/template.html \(\d+\.\d+ms\)/)
              expect(lines[2]).to include("\"template_rendered\":{\"name\":\"spec/support/rails/templates/template.html\"")
            end
          end
        end
      end

      context "with a debug level" do
        around(:each) do |example|
          old_level = logger.level
          logger.level = ::Logger::DEBUG
          example.run
          logger.level = old_level
        end

        it "should not log the start of the rendering" do
          dispatch_rails_request("/action_view_log_subscriber")
          expect(io.string.scan("Rendered spec/support/rails/templates/template.html").length).to eq(1)
          expect(io.string).not_to include("Rendering")
        end
      end
    end
  end

  if defined?(::ActionView::LogSubscriber::Start)
    describe "integrate!" do
      # Since Rails 7.1, ActionView::LogSubscriber.attach_to subscribes these listeners next to the
      # subscriber itself. They log "Rendering ..." at debug level.
      it "should remove the listeners logging the start of a rendering" do
        notifier = ::ActiveSupport::Notifications.notifier
        listeners = %w(render_template.action_view render_layout.action_view).flat_map do |name|
          notifier.respond_to?(:all_listeners_for) ? notifier.all_listeners_for(name) : notifier.listeners_for(name)
        end

        expect(listeners.map(&:delegate).grep(::ActionView::LogSubscriber::Start)).to be_empty
      end
    end
  end

  if defined?(described_class::LogtailLogSubscriber)
    describe described_class::LogtailLogSubscriber do
      let(:event) do
        event = Struct.new(:duration, :payload)
        event.new(2.0, identifier: "path/to/template.html")
      end

      around(:each) do |example|
        old_level = logger.level
        logger.level = ::Logger::INFO
        example.run
        logger.level = old_level
      end

      describe "#render_template" do
        it "should render the collection" do
          log_subscriber = described_class.new
          allow(log_subscriber).to receive(:logger).and_return(logger)
          log_subscriber.render_template(event)
          expect(io.string.strip).to include("Rendered path/to/template.html (2.0ms)")
        end
      end

      describe "#render_partial" do
        it "should render the collection" do
          log_subscriber = described_class.new
          allow(log_subscriber).to receive(:logger).and_return(logger)
          log_subscriber.render_partial(event)
          expect(io.string.strip).to include("Rendered path/to/template.html (2.0ms)")
        end
      end

      describe "#render_collection" do
        it "should render the collection" do
          log_subscriber = described_class.new
          allow(log_subscriber).to receive(:logger).and_return(logger)
          log_subscriber.render_collection(event)

          if log_subscriber.respond_to?(:render_count, true)
            expect(io.string.strip).to include("Rendered collection of path/to/template.html [ times] (2.0ms)")
          else
            expect(io.string.strip).to include("Rendered path/to/template.html (2.0ms)")
          end
        end
      end
    end
  end

  # Remove blank lines since Rails does this to space out requests in the logs
  def clean_lines(lines)
    lines.select { |line| !line.start_with?(" @metadata") }
  end
end
