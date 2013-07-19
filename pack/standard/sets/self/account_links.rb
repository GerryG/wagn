# -*- encoding : utf-8 -*-
format :html do

  view :raw do |args|
    #ENGLISH
    %{<span id="logging">#{
      if Account.logged_in?
        ucard = Account.current
        %{
          #{ link_to ucard.name, "#{Wagn::Conf[:root_path]}/#{ucard.cardname.url_key}", :id=>'my-card-link' }
          #{
            if Account.create_ok?
              link_to 'Invite a Friend', Wagn::Conf[:root_path] + '/new/' + Card[:invite].name, :id=>'invite-a-friend-link'
            end
          }
          #{ link_to 'Sign out', "#{Wagn::Conf[:root_path]}/signout",                                      :id=>'signout-link' }
        }
      else
        %{
          #{ if Card.new(:typecode=>'account_request').ok? :create
               link_to 'Sign up', Wagn::Conf[:root_path] + '/new/' + Card[:account_request].name , :id=>'signup-link'
             end }
          #{ link_to 'Sign in', Wagn::Conf[:root_path] + '/new/' + Card[:session].name, :id=>'signin-link' }
        }
      end }
    </span>}
  end

end
