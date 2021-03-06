class PersonPresenter < Whitehall::Decorators::Decorator
  delegate_instance_methods_of Person

  def available_in_multiple_languages?
    translated_locales.length > 1
  end

  def translated_locales
    model.translated_locales
  end

  def current_role_appointments
    model.current_role_appointments.map { |ra| RoleAppointmentPresenter.new(ra, context) }
  end

  def previous_role_appointments
    model.previous_role_appointments.map { |ra| RoleAppointmentPresenter.new(ra, context) }
  end

  def current_ministerial_roles
    model.current_ministerial_roles.map { |role| RolePresenter.new(role, context) }
  end

  def announcements
    search_results = Whitehall.search_client.search(
      filter_people: model.slug,
      count: 10,
      order: "-public_timestamp",
      reject_content_purpose_supergroup: "other",
      fields: %w[title link content_store_document_type public_timestamp],
    )["results"]

    search_results.map do |item|
      metadata = {}

      if item["public_timestamp"]
        metadata[:public_updated_at] = Date.parse(item["public_timestamp"])
      end

      if item["content_store_document_type"]
        metadata[:document_type] = item["content_store_document_type"].humanize
      end

      {
        link: {
          text: item["title"],
          path: item["link"],
        },
        metadata: metadata,
      }
    end
  end

  def speeches
    model.speeches.latest_published_edition.order("delivered_on desc").limit(10).map { |s| SpeechPresenter.new(s, context) }
  end

  def biography
    context.govspeak_to_html(model.biography_appropriate_for_role)
  end

  def link(options = {})
    name = ""
    name << "<span class='app-person-link__title'>The Rt Hon</span> " if privy_counsellor?
    name << "<span class='app-person-link__name govuk-!-padding-0 govuk-!-margin-0}'>#{name_without_privy_counsellor_prefix}</span>"
    context.link_to name.html_safe, path, options.merge(class: "app-person-link")
  end

  def path
    context.person_path model
  end

  def image
    if (img = image_url(:s216))
      context.image_tag img, alt: name, loading: "lazy"
    end
  end
end
