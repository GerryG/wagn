require File.expand_path(File.join(File.dirname(__FILE__), "..", "support", "paths"))

Given /^(.*) (is|am) watching "([^\"]+)"$/ do |user, verb, cardname|
  user = Session.authorized.name if user == "I"
  step "the card #{cardname}+*watchers contains \"[[#{user}]]\""
end

Then /^(.*) should be notified that "(.*)"$/ do |username, subject|
  account = username=='I' ? Session.authorized : Card[username].trait_card(:account)
  user = Session.from_id account.id
  email = user.email
  warn "sbe notified #{account.inspect}, #{user.inspect}, #{email.inspect}"
  begin
    step %{"#{email}" should receive 1 email}
  rescue RSpec::Expectations::ExpectationNotMetError=>e
    raise RSpec::Expectations::ExpectationNotMetError, "#{e.message}\n Found the following emails:\n\n #{all_emails.to_s}"
  end
  open_email(email, :with_subject => /#{subject}/)
end

Then /^No notification should be sent$/ do
  all_emails.should be_empty
end
