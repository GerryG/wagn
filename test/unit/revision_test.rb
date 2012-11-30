require File.expand_path('../test_helper', File.dirname(__FILE__))
class RevisionTest < ActiveSupport::TestCase

  def setup
    super
    setup_default_account
  end

  def test_revise
    author1 = Account.find_by_email('joe@user.com')
    author2 = Account.find_by_email('sara@user.com')
    author_acct_cd1 = Card[author1.account_id] and author_cd1 = author_acct_cd1.trunk
    author_acct_cd2 = Card[author2.account_id] and author_cd2 = author_acct_cd2.trunk
    Account.as_bot {
      rc1=author_cd1.fetch(:new=>{}, :trait=>:roles)
      rc1 << Card::AdminID
      rc2 = author_cd2.fetch(:new=>{}, :trait=>:roles)
      #author1, author2 = User.find(:all, :limit=>2)
      rc1 << Card::AdminID
      rc2 << Card::AdminID
      author_cd1.save
      author_cd2.save
    }
    Account.session = author_acct_cd1
    card = newcard( 'alpha', 'stuff')
    Account.session = author_acct_cd2
    card.content = 'boogy'
    card.save
    card.reload

    assert_equal 2, card.revisions.length, 'Should have two revisions'
    assert_equal author_cd2.name, card.current_revision.creator.name, 'current author'
    assert_equal author_cd1.name, card.revisions.first.creator.name,  'first author'
  end

=begin
  # FIXME- should revisit what we want to have happen here; for now keep saving unchanged revisions..
  def test_revise_content_unchanged
    @card = newcard('alpha', 'banana')
    last_revision_before = @card.current_revision
    revisions_number_before = @card.revisions.size

    @card.content = (@card.current_revision.content)
    @card.save

    assert_equal last_revision_before, @card.current_revision(true)
    assert_equal revisions_number_before, @card.revisions.size
  end
=end

=begin #FIXME - don't think this is used by any controller. we'll see what breaks
  def test_rollback
    @card = newcard("alhpa", "some test content")
    @user = Card['quentin'].account
    @card.content = "spot two"; @card.save
    @card.content = "spot three"; @card.save
    assert_equal 3, @card.revisions(true).length, "Should have three revisions"
    @card.current_revision(true)
    @card.rollback(0)
    assert_equal "some test content", @card.current_revision(true).content
  end
=end

  def test_save_draft
    @card = newcard("mango", "foo")
    @card.save_draft("bar")
    assert_equal 1, @card.drafts.length
    @card.save_draft("booboo")
    assert_equal 1, @card.drafts.length
    assert_equal "booboo", @card.drafts[0].content
  end

end
