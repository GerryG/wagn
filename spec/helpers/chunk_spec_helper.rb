module ChunkSpecHelper
#  include CardBuilderMethods
  include AuthenticatedTestHelper

  # This module is to be included in unit tests that involve matching chunks.
  # It provides a easy way to test whether a chunk matches a particular string
  # and any the values of any fields that should be set after a match.
  class ContentStub < String
    include ChunkManager

    attr_reader :renderer

    def initialize str
      super
      @renderer = Wagn::Renderer::Html.new nil
      init_chunk_manager
    end

    def card
    end

    def render_link *a
    end

  end

  def setup_user user
    Account.user = 'joe_user'
  end

  def render_test_card card
    r = Wagn::Renderer.new card
    r.add_name_context card.name
    r.process_content
  end

  def assert_difference object, method = nil, difference = 1
    initial_value = object.send method
    yield
    assert_equal initial_value + difference, object.send(method), "#{object}##{method}"
  end

  def assert_no_difference object, method, &block
    assert_difference object, method, 0, &block
  end

  # Asserts that test_text doesn't match the chunk_type
  def no_match chunk_type, test_text
    #warn "no match #{chunk_type}, #{test_text}"
    chunk_type.pattern.should_not match test_text
  end

  def assert_conversion_does_not_apply chunk_type, str
    #warn "c dna #{chunk_type}, #{str}"
    processed_str = ContentStub.new str.dup
    chunk_type.apply_to processed_str
    processed_str.find_chunks.count.should == 0
  end

  private

  # Asserts a number of tests for the given type and text.
  # Asserts a number of tests for the given type and text.
  def match_chunk chunk_type, test_text, expected_chunk_state
    chunk_type.pattern.should match test_text

    content = ContentStub.new test_text
      chunk_type.apply_to content

    # Test if requested parts are correct.
    expected_chunk_state.each_pair do |a_method, expected_value|
      content.chunks.last.should be_instance_of chunk_type
      content.chunks.last.should respond_to a_method
      content.chunks.last.send(a_method.to_sym).should == expected_value # "Wrong #{a_method} value"
    end
  end
  
  def newcard name, content=""
    Card.create! :name=>name, :content=>content
  end

=begin
  def match_chunk type, test_text, expected
    pattern = type.pattern
    assert_match pattern, test_text
    pattern =~ test_text   # Previous assertion guarantees match
    chunk = type.new $~

    # Test if requested parts are correct.
    for method_sym, value in expected do
      assert_respond_to chunk, method_sym
      assert_equal value, chunk.method(method_sym).call, "Checking value of '#{method_sym}'"
    end
  end
=end
end


