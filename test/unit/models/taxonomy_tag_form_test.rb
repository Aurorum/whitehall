require 'test_helper'

class TaxonomyTagFormTest < ActiveSupport::TestCase
  include TaxonomyHelper

  test "#load when publishing-api returns 404, selected_taxons should be '[]'" do
    content_id = "64aadc14-9bca-40d9-abb4-4f21f9792a05"

    body = {
      "error" => {
        "code" => 404,
        "message" => "Could not find link set with content_id: #{content_id}"
      }
    }.to_json

    stub_request(:get, %r{.*/v2/links/#{content_id}.*})
      .to_return(body: body, status: 404)

    form = TaxonomyTagForm.load(content_id)

    assert_equal form.selected_taxons, []
  end

  test '#load should request links to publishing-api' do
    content_id = "64aadc14-9bca-40d9-abb6-4f21f9792a05"
    taxons = ["c58fdadd-7743-46d6-9629-90bb3ccc4ef0"]

    publishing_api_has_links(
      "content_id" => "64aadc14-9bca-40d9-abb6-4f21f9792a05",
      "links" => {
        "taxons" => taxons,
      },
      "version" => 1
    )

    form = TaxonomyTagForm.load(content_id)

    assert_equal(form.content_id, content_id)
    assert_equal(form.selected_taxons, taxons)
    assert_equal(form.previous_version, 1)
  end

  test '#most_specific_taxons ignores taxons if there is a more specific one' do
    stub_taxonomy_with_all_taxons

    selected_taxons = [
      grandparent_taxon_content_id,
      parent_taxon_content_id,
      child_taxon_content_id
    ]

    form = TaxonomyTagForm.new(
      selected_taxons: selected_taxons,
      content_id: "abc",
      previous_version: 1,
      all_taxons: Taxonomy::GovukTaxonomy.new.all_taxons
    )

    assert_equal [child_taxon_content_id], form.most_specific_taxons
  end

  test '#published_taxons returns all published taxons tagged to the content item' do
    content_id = "64aadc14-9bca-40d9-abb6-4f21f9792a05"

    publishing_api_has_links(
      "content_id" => content_id,
      "links" => {
        "taxons" => %w[bbbb cccc]
      },
      "version" => 1
    )

    Taxonomy::GovukTaxonomy
      .any_instance.stubs(:matching_against_published_taxons)
      .with(%w[bbbb cccc])
      .returns(['bbbb'])

    form = TaxonomyTagForm.load(content_id)
    assert_equal ['bbbb'], form.published_taxons
  end

  test '#visible_draft_taxons returns all draft taxons tagged to the content item' do
    content_id = "64aadc14-9bca-40d9-abb6-4f21f9792a05"

    publishing_api_has_links(
      "content_id" => content_id,
      "links" => {
        "taxons" => %w[bbbb cccc]
      },
      "version" => 1
    )

    Taxonomy::GovukTaxonomy
      .any_instance.stubs(:matching_against_visible_draft_taxons)
      .with(%w[bbbb cccc])
      .returns(['cccc'])

    form = TaxonomyTagForm.load(content_id)
    assert_equal ['cccc'], form.visible_draft_taxons
  end

  test '#invisible_draft_taxons returns all invisible draft taxons tagged to the content item' do
    content_id = "64aadc14-9bca-40d9-abb6-4f21f9792a05"

    publishing_api_has_links(
      "content_id" => content_id,
      "links" => {
        "taxons" => [
          'published-taxon',
          'draft-taxon',
          'invisible-draft-taxon',
        ]
      },
      "version" => 1
    )

    form = TaxonomyTagForm.load(content_id)

    form.stubs(:published_taxons).returns(["published-taxon"])
    form.stubs(:visible_draft_taxons).returns(["draft-taxon"])

    assert_equal ['invisible-draft-taxon'], form.invisible_draft_taxons
  end
end
