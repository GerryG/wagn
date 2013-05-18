# -*- encoding : utf-8 -*-
class AdminController < CardController
  layout 'application'
  before_filter :admin_only, :except=>:setup
  
  def missing # dummy to see if I can spot where this odd route is coming from
    Rails.logger.warn "admin/missing ???"
  end

  def setup
    raise(Wagn::Oops, "Already setup") if Account.first_login?
    Wagn::Conf[:recaptcha_on] = false
    if request.post?
     begin
      Account.as_bot do
        @card = Card.new params[:card].merge(:type=>Card::UserID)
        aparams = params[:account]
        aparams[:name] = @card.name
        acct = Account.new( aparams ).active
        @account = card.account = Account.new( aparams ).active
        Rails.logger.warn "acct setup #{acct.inspect}, #{card.inspect}, #{@card.account}"
        set_default_request_recipient

        card.save

        Rails.logger.warn "ext id = #{@account.inspect}"

        if @card.errors.empty?
          roles_card = card.fetch :trait=>:roles, :new=>{}
          roles_card.content = "[[#{Card[Card::AdminID].name}]]"
          roles_card.save
          self.current_account_id = @card.id
          Account.current_id = card.id
          Account.first_login!
          flash[:notice] = "You're good to go!"
          redirect_to Card.path_setting('/')
        else
          Rails.logger.warn "setup error #{@card.errors.map {|e| e.to_s}*', '}"
          flash[:notice] = "Durn, setup went awry..."
        end
      end
     rescue Exception => e
       Rails.logger.warn "setup except #{e.inspect}"
       raise e
     end
    else
      @card = Card.new params[:card] #should prolly skip defaults
      aparams = params[:account] || {}
      aparams[:name] = @card.name
      @account = Account.new aparams
    end
  end

  def show_cache
    key = params[:id].to_name.key
    @cache_card = Card.fetch key
    @db_card = Card.find_by_key key
  end

  def clear_cache
    Wagn::Cache.reset_global
    render_text 'Cache cleared'
  end

  def memory
    oldmem = session[:memory]
    session[:memory] = total = profile_memory
    
    render_text %{      
      <p>Total: #{total} </p>
      #{
        if oldmem
          %{ <p>Diff: #{total - oldmem}</p> }
        end
      }
    }
  end


  def tasks
    render_text %{
      <h1>Global Permissions - REMOVED</h1>
      <p>&nbsp;</p>
      <p>After moving so much configuration power into cards, the old, weaker global system is no longer needed.</p>
      <p>&nbsp;</p>
      <p>Account permissions are now controlled through +*account cards and role permissions through +*role cards.</p>
    }
  end
  
  def repair_references
    Card::Reference.repair_all
    stats 'References Repaired'
  end


  def stats msg
    render_text %{
      <h2>#{msg}</h2>
      <p>cards: #{Card.where(:trash=>false).count}</p>
      <p>trashed cards: #{Card.where(:trash=>true).count}</p>
      <p>revisions: #{Card::Revision.count}</p>
      <p>references: #{Card::Reference.count}</p>
    }
  end

  def empty_trash
    Card.empty_trash
    stats 'Trash Emptied'
  end
  
  def delete_old_revisions
    Card::Revision.delete_old
    stats 'Old Revisions Deleted'
  end

  def delete_old_sessions
    if params[:months] and params[:months].to_i > 0
      sql = 'DELETE FROM sessions WHERE updated_at < DATE_SUB(NOW(), INTERVAL %s MONTH);' % params[:months]
      ActiveRecord::Base.connection.execute(sql)
      render_text 'deleted'
    else
      render_text %{
        <form>Delete session records last updated more than <input name="months"/> months ago</form>
      }
    end
  end

  private

  def get_current_memory_usage
    `ps -o rss= -p #{Process.pid}`.to_i
  end
  
  def profile_memory(&block)
    before = get_current_memory_usage
    file, line, _ = caller[0].split(':')
    if block_given?
      instance_eval(&block)
      (get_current_memory_usage - before) / 1024.0
    else
      before = 0
      (get_current_memory_usage - before) / 1024.0
    end
  end



  def render_text response
    render :text =>response, :layout=> true
  end
  
  def admin_only
    raise Wagn::PermissionDenied unless Account.always_ok?
  end

  def set_default_request_recipient
    to_card = Card.fetch '*request+*to', :new=>{}
    to_card.content=params[:account][:email]
    to_card.save
  end
end
