# -*- encoding : utf-8 -*-
require File.expand_path('../test_helper', File.dirname(__FILE__))

class Card::ContentTest < ActiveSupport::TestCase

#  def test_clean_tables
#    assert_equal '     foo     ', Card::Content.clean!("<table> <tbody><tr><td>foo</td></tr> </tbody></table>")
#  end

  def test_clean
    assert_equal ' [grrew][/wiki/grrew]ss ',Card::Content.clean!(' [grrew][/wiki/grrew]ss ')
    assert_equal '<p>html<div>with</div> funky tags</p>', Card::Content.clean!('<p>html<div class="boo">with</div><monkey>funky</butts>tags</p>')
  end

  def test_clean_should_allow_permitted_classes
    assert_equal '<span class="w-spotlight">foo</span>', Card::Content.clean!('<span class="w-spotlight">foo</span>')
    assert_equal '<p class="w-highlight">foo</p>', Card::Content.clean!('<p class="w-highlight">foo</p>')
  end

  def test_clean_should_disallow_nonpermitted_classes_in_spans
    assert_equal '<span>foo</span>', Card::Content.clean!('<span class="banana">foo</span>')
  end

  def test_clean_should_allow_permitted_attributes
    assert_equal '<img src="foo">',   Card::Content.clean!('<img src="foo">')
    assert_equal '<img alt="foo">',   Card::Content.clean!('<img alt="foo">')
    assert_equal '<img title="foo">', Card::Content.clean!('<img title="foo">')
    assert_equal '<a href="foo">',    Card::Content.clean!('<a href="foo">')
    assert_equal '<code lang="foo">', Card::Content.clean!('<code lang="foo">')
    assert_equal '<blockquote cite="foo">', Card::Content.clean!('<blockquote cite="foo">')
  end

  def test_clean_should_not_allow_nonpermitted_attributes
    assert_equal '<img>',   Card::Content.clean!('<img size="25">')
    assert_equal '<p>',   Card::Content.clean!('<p font="blah">')
  end

  def test_clean_should_remove_comments
    assert_equal 'yo', Card::Content.clean!('<!-- not me -->yo')
    assert_equal 'joe', Card::Content.clean!('<!-- not me -->joe<!-- not me -->')
  end
end
