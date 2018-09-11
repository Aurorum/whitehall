# encoding: utf-8

require 'test_helper'

class HtmlAttachmentTest < ActiveSupport::TestCase
  test '#govspeak_content_body_html returns the computed HTML as an HTML safe string' do
    Sidekiq::Testing.inline! do
      attachment = create(:html_attachment, body: 'Some govspeak')

      assert attachment.reload.govspeak_content_body_html.html_safe?
      assert_equivalent_html "<div class=\"govspeak\"><p>Some govspeak</p></div>",
        attachment.govspeak_content_body_html
    end
  end

  test 'associated govspeak content is deleted with the html attachment' do
    attachment = create(:html_attachment)
    govspeak_content = attachment.govspeak_content

    attachment.destroy

    refute GovspeakContent.exists?(govspeak_content.id)
  end

  test '#deep_clone deep clones the HTML attachment, body, content_id and slug' do
    attachment = create(:html_attachment)

    clone = attachment.deep_clone

    assert attachment.id != clone.id
    assert clone.new_record?
    assert_equal attachment.title, clone.title
    assert_equal attachment.govspeak_content_body, clone.govspeak_content_body
    assert_equal attachment.slug, clone.slug
    assert_equal attachment.content_id, clone.content_id
  end

  test '#url returns absolute path to the draft stack when previewing' do
    edition = create(:draft_publication, :with_html_attachment)
    attachment = edition.attachments.first

    expected = "https://draft-origin.test.gov.uk/government/publications/"
    expected += "#{edition.slug}/#{attachment.slug}?preview=#{attachment.id}"
    actual = attachment.url(preview: true, full_url: true)

    assert_equal expected, actual
  end

  test '#url returns absolute path to the live site when not previewing' do
    edition = create(:published_publication, :with_html_attachment)
    attachment = edition.attachments.first

    expected = "https://www-origin.test.gov.uk/government/publications/"
    expected += "#{edition.slug}/#{attachment.slug}"
    actual = attachment.url(full_url: true)

    assert_equal expected, actual
  end

  test '#url returns relative path by default' do
    edition = create(:published_publication, :with_html_attachment)
    attachment = edition.attachments.first
    assert_equal "/government/publications/#{edition.slug}/#{attachment.slug}", attachment.url
  end

  test "slug is copied from previous edition's attachment" do
    edition = create(:published_publication, attachments: [
      build(:html_attachment, title: "an-html-attachment")
    ])
    draft = edition.create_draft(create(:writer))

    assert_equal "an-html-attachment", draft.attachments.first.slug
  end

  test "slug is updated when the title is changed if edition is unpublished" do
    attachment = build(:html_attachment, title: "an-html-attachment")

    create(:draft_publication, attachments: [attachment])

    attachment.title = "a-new-title"
    attachment.save
    attachment.reload

    assert_equal "a-new-title", attachment.slug
  end

  test "slug is not updated when the title is changed if edition is published" do
    edition = create(:published_publication, attachments: [
      build(:html_attachment, title: "an-html-attachment")
    ])
    draft = edition.create_draft(create(:writer))
    attachment = draft.attachments.first

    attachment.title = "a-new-title"
    attachment.save
    attachment.reload

    assert_equal "an-html-attachment", attachment.slug
  end

  test "slug is not updated when the title has been changed in a prior published edition" do
    edition = create(:published_publication, attachments: [
      build(:html_attachment, title: "an-html-attachment")
    ])
    draft = edition.create_draft(create(:writer))
    attachment = draft.attachments.first

    attachment.title = "a-new-title"
    attachment.save
    attachment.reload

    draft.change_note = 'Edited HTML attachment title'
    force_publish(draft)

    second_draft = draft.create_draft(create(:writer))
    second_draft_attachment = second_draft.attachments.first

    assert_equal "an-html-attachment", attachment.slug
    assert_equal "an-html-attachment", second_draft_attachment.slug
  end

  test "slug is not created for non-english attachments" do
    # Additional attachment to ensure the duplicate detection behaviour isn't triggered
    create(:html_attachment, locale: "fr")
    attachment = create(:html_attachment, locale: "ar", title: "المملكة المتحدة والمملكة العربية السعودية")

    assert attachment.slug.blank?
    assert_equal attachment.id.to_s, attachment.to_param
  end

  test "slug is created for english-only attachments" do
    attachment = create(:html_attachment, locale: "en", title: "We have a bias for action")

    expected_slug = "we-have-a-bias-for-action"
    assert_equal expected_slug, attachment.slug
    assert_equal expected_slug, attachment.to_param
  end

  test "slug is cleared when changing from english to non-english" do
    attachment = create(:html_attachment, locale: "en")

    attachment.update_attributes!(locale: "fr")
    assert attachment.slug.blank?
  end

  test "#translated_locales lists only the attachment's locale" do
    assert_equal %w[en], HtmlAttachment.new.translated_locales
    assert_equal %w[cy], HtmlAttachment.new(locale: "cy").translated_locales
  end

  test "attachment with the same base path as a previously deleted attachment
    retains the content_id" do
    content_id = "2f142514-15bf-4779-b651-5a9aaf6df93c"
    deleted_attachment = create(
      :html_attachment,
      content_id: content_id,
      title: "booyah",
      attachable: build(:published_publication)
    )
    first_edition = deleted_attachment.attachable
    deleted_attachment.destroy

    new_draft = first_edition.create_draft(first_edition.creator)
    new_attachment = create(
      :html_attachment,
      title: "booyah",
      attachable: new_draft
    )

    assert_equal content_id, new_attachment.content_id
  end

  test "attachment with the same title but different base_path does not retain
    the content_id" do
    deleted_attachment = create(
      :html_attachment,
      title: "original title",
      attachable: build(:published_publication)
    )
    #this will have slug `original-title`
    deleted_attachment.update_attributes(title: "new title")

    first_edition = deleted_attachment.attachable
    deleted_attachment.destroy

    new_draft = first_edition.create_draft(first_edition.creator)
    #this will have slug `new-title`
    new_attachment = create(
      :html_attachment,
      title: "new title",
      attachable: new_draft
    )

    assert_not_equal new_attachment.content_id, deleted_attachment.content_id
  end

  test "translations with the same title retain the same content_id" do
    content_id = "97660b60-d4cd-4bfe-b9f5-d95d20e78449"
    first_attachment = create(
      :html_attachment,
      title: "Le Boeuf",
      locale: "fr",
      content_id: content_id
    )

    edition = first_attachment.attachable
    first_attachment.destroy
    second_attachment = create(
      :html_attachment,
      title: "Le Boeuf",
      locale: "fr",
      attachable: edition
    )

    assert_equal content_id, second_attachment.content_id
  end

  test "translations with the different titles get different content_id" do
    content_id = "97660b60-d4cd-4bfe-b9f5-d95d20e78449"
    first_attachment = create(
      :html_attachment,
      title: "Le Boeuf",
      locale: "fr",
      content_id: content_id
    )

    edition = first_attachment.attachable
    first_attachment.destroy
    second_attachment = create(
      :html_attachment,
      title: "Les Oeufs",
      locale: "fr",
      attachable: edition
    )

    assert_not_equal content_id, second_attachment.content_id
  end

  test "attachment with an unused base path gets a new content_id" do
    first_attachment = create(
      :html_attachment,
      title: "booyah",
      attachable: build(:published_publication)
    )
    published_edition = first_attachment.attachable
    new_draft = published_edition.create_draft(published_edition.creator)
    second_attachment = create(
      :html_attachment,
      title: "kasha",
      attachable: new_draft
    )

    assert_not_equal first_attachment.content_id, second_attachment.content_id
  end

  test "#rendering_app returns government_frontend" do
    assert_equal "government-frontend", HtmlAttachment.new.rendering_app
  end
end
