Then(/^I should see the fact checking feedback "([^"]*)"$/) do |comments|
  assert_selector ".fact_check_request .comments", text: comments
end

Then(/^I should see the pending fact check request to "([^"]*)" for policy "([^"]*)"$/) do |email_address, title|
  visit admin_policy_path(Policy.find_by!(title: title))
  assert_selector ".fact_check_request.pending .from", text: email_address
end

Then(/^I should see that those responsible for the policy are:$/) do |table|
  table.hashes.each do |row|
    person = find_person(row["Person"])
    assert_selector ".meta a", text: person.name
  end
end

Then(/^I should see that "([^"]*)" is the policy body$/) do |policy_body|
  assert_selector ".body", text: policy_body
end

Then(/^I should see that the policy only applies to:$/) do |nation_names|
  message = nation_names.raw.flatten.sort.to_sentence
  assert_selector inapplicable_nations_selector, text: message
end

Then(/^I should see a link to the preview version of the publication "([^"]*)"$/) do |publication_title|
  publication = Publication.find_by!(title: publication_title)
  visit admin_edition_path(publication)
  expected_preview_url = "http://draft-origin.test.gov.uk/government/publications/#{publication.slug}"

  assert_equal expected_preview_url, find("a.preview_version")[:href]
end

Then(/^I should see that it was rejected by "([^"]*)"$/) do |rejected_by|
  assert_selector ".rejected_by", text: rejected_by
end

Then(/^I can see links to the recently changed document "([^"]*)"$/) do |title|
  edition = Edition.find_by!(title: title)
  assert_selector "#recently-changed #{record_css_selector(edition)} a", text: edition.title
end

Then(/^I should see a link to "([^"]*)" in the list of related documents$/) do |title|
  edition = Edition.find_by(title: title)
  assert_match admin_edition_path(edition), find("#inbound-links a", text: title)[:href]
end

Then(/^I should not see a link to "([^"]*)" in the list of related documents$/) do |title|
  assert_no_selector "#inbound-links a", text: title
end

Given(/^a (.*?) policy "([^"]*)" for the organisation "([^"]*)"$/) do |state, title, organisation|
  org = create(:organisation, name: organisation)
  create("#{state}_policy", title: title, organisations: [org])
end

Given(/^a (.*?) policy "([^"]*)" for the organisations "([^"]*)" and "([^"]*)"$/) do |state, title, organisation_1, organisation_2|
  organisation_1 = create(:organisation, name: organisation_1)
  organisation_2 = create(:organisation, name: organisation_2)
  create("#{state}_policy", title: title, organisations: [organisation_1, organisation_2])
end
