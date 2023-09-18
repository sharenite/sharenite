# frozen_string_literal: true

# Karafka configuration
class KarafkaApp < Karafka::App
  # rubocop:disable Metrics/BlockLength
  setup do |config|
    config.kafka = { "bootstrap.servers": "sharenite-kafka:9092" }
    config.client_id = "sharenite_app"
    # Recreate consumers with each batch. This will allow Rails code reload to work in the
    # development mode. Otherwise Karafka process would not be aware of code changes
    config.consumer_persistence = !Rails.env.development?
    config.concurrency = 10

    config.producer =
      ::WaterDrop::Producer.new do |producer_config|
        # Use all the settings already defined for consumer by default
        producer_config.kafka = ::Karafka::Setup::AttributesMap.producer(config.kafka.dup)
        producer_config.logger = config.logger

        # Alter things you want to alter
      end

    config
      .producer
      .monitor
      .subscribe("error.occurred") do |event|
        error = event[:error]
        Appsignal.set_error(error)
        p "WaterDrop error occurred: #{error}"
      end
  end
  # rubocop:enable Metrics/BlockLength

  # Comment out this part if you are not using instrumentation and/or you are not
  # interested in logging events for certain environments. Since instrumentation
  # notifications add extra boilerplate, if you want to achieve max performance,
  # listen to only what you really need for given environment.
  Karafka.monitor.subscribe(Karafka::Instrumentation::LoggerListener.new)
  # Karafka.monitor.subscribe(Karafka::Instrumentation::ProctitleListener.new)
  Karafka.producer.monitor.subscribe(WaterDrop::Instrumentation::LoggerListener.new(Karafka.logger))

  routes.draw do
    # Uncomment this if you use Karafka with ActiveJob
    # You ned to define the topic per each queue name you use
    active_job_topic :default
    topic "library.sync" do
      consumer LibrarySyncConsumer

      dead_letter_queue(
        # Name of the target topic where problematic messages should be moved to
        topic: "dead.messages",
        # How many times we should retry processing with a back-off before
        # moving the message to the DLQ topic and continuing the work
        #
        # If set to zero, will not retry at all.
        max_retries: Rails.application.credentials.dlq_retries || 10
      )

      long_running_job true
    end

    topic "dead.messages" do
      consumer DeadMessagesConsumer
    end
  end
end

require "karafka/web"

Karafka::Web.setup do |config|
  config.ui.sessions.secret = ENV.fetch('KARAFKA_UI_SECRET', nil)
end

Karafka::Web.enable!
