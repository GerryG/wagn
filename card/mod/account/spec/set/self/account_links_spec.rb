# -*- encoding : utf-8 -*-

describe Card::Set::Self::AccountLinks do
  it "has a 'my card' link" do
    assert_view_select render_card(:core, name: "*account links"),
                       'span[id="logging"]' do
      assert_select 'a[class=~"my-card-link"]', text: "Joe User"
    end
  end
end
