module Wagn
  include Sets
  #module Set::Self::Session

    event_handler :create, :name=>:session do |*a|
      warn "signin #{params[:login]}"
      if params[:login]
        password_authentication params[:login], params[:password]
      end
    end

    event_handler :delete, :name=>:session do |*a|
      warn "signout #{params.inspect}"
      self.session_user = nil
      flash[:notice] = "Successfully signed out"
      redirect_to Card.path_setting('/')  # previous_location here can cause infinite loop.  ##  Really?  Shouldn't.  -efm
    end
  #end
end
