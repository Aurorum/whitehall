require "gds_api/helpers"

class EmailTopicChecker
  include GdsApi::Helpers

  # The govuk-delivery mongo db stores absolute paths for feed_urls in its
  # db.topics collection. This environment variable lets us swap out the feed
  # urls generated by Whitehall to match the origin host.
  ORIGIN = URI.parse(ENV.fetch("ORIGIN", "https://www.gov.uk"))

  # We make a request to the content store to look up the supertypes for the
  # document as these are used in email-alert-api's SubscriberListQuery. Set
  # this environment variable to skip this check. This is useful if you don't
  # have any data in your local content store and still want the code to run.
  IGNORE_SUPERTYPES = ENV["IGNORE_SUPERTYPES"].present?

  def self.check(content_id)
    new(content_id).check
  end

  attr_accessor :document

  def initialize(content_id)
    self.document = Document.find_by!(content_id: content_id)
  end

  def check
    edition = document.published_edition
    raise "No published edition" unless edition

    feed_urls = feed_urls(edition)
    govuk_topics = feed_urls.map { |url| govuk_delivery_topic(url) }.compact.sort

    presented_edition = PublishingApiPresenters.presenter_for(edition)
    supertypes = content_store_supertypes(presented_edition)
    email_topics = email_alert_api_topics(presented_edition, supertypes)

    puts "\ngovuk-delivery feed urls:"
    puts feed_urls

    puts "\ngovuk-delivery topics:"
    puts govuk_topics

    puts "\nemail-alert-api topics:"
    puts email_topics

    additional_govuk = (govuk_topics - email_topics).presence || "None"
    puts "\nadditional govuk-delivery topics:"
    puts additional_govuk

    additional_email = (email_topics - govuk_topics).presence || "None"
    puts "\nadditional email-alert-api topics:"
    puts additional_email
  end

  def govuk_delivery_topic(feed_url)
    feed_uri = URI.parse(feed_url)
    feed_uri.scheme = ORIGIN.scheme
    feed_uri.host = ORIGIN.host

    signup_url = Whitehall.govuk_delivery_client.signup_url(feed_uri.to_s)
    signup_uri = URI.parse(signup_url)
    signup_params = CGI.parse(signup_uri.query)

    signup_params.fetch("topic_id").first
  rescue GdsApi::HTTPNotFound
    nil
  end

  def content_store_supertypes(presented_edition)
    return {} if IGNORE_SUPERTYPES

    base_path = presented_edition.content.to_h.fetch(:base_path)
    content = Whitehall.content_store.content_item(base_path).to_h
    content.slice("email_document_supertype", "government_document_supertype").symbolize_keys
  end

  def email_alert_api_topics(presented_edition, supertypes)
    content = presented_edition.content
    links = presented_edition.links
    details = content[:details]
    tags = details[:tags] if details

    params = {
      links: strip_empty_arrays(links || {}),
      tags: strip_empty_arrays(tags || {}),
      document_type: content[:document_type],
    }.merge(supertypes)

    puts "\nemail-alert-api params:"
    puts params.inspect

    response = email_alert_api.topic_matches(params)
    response.to_h.fetch("topics")
  rescue GdsApi::HTTPNotFound
    nil
  end

  def feed_urls(edition)
    generator = Whitehall::GovUkDelivery::SubscriptionUrlGenerator.new(edition)
    generator.subscription_urls
  end

  def links_hash(feed_url)
    UrlToSubscriberListCriteria.new(feed_url).convert
  end

  def strip_empty_arrays(hash)
    hash.reject { |_, values| values.empty? }
  end
end
