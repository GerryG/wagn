# encoding: utf-8
require File.expand_path('../../spec_helper', File.dirname(__FILE__))

describe Wagn::Cache do
  describe "with nil store" do
    before do
      mock(Wagn::Cache).generate_cache_id.times(2).returns("cache_id")
      @cache = Wagn::Cache.new :prefix=>"prefix"
    end

    describe "#basic operations" do
      it "should work" do
        @cache.write("a", "foo")
        @cache.read("a").should == "foo"
        @cache.fetch("b") { "bar" }
        @cache.read("b").should == "bar"
        @cache.reset
      end
    end
  end

  describe "with same cache_id" do
    before :each do
      @store = ActiveSupport::Cache::MemoryStore.new
      mock(Wagn::Cache).generate_cache_id().returns("cache_id")
      @cache = Wagn::Cache.new :store=>@store, :prefix=>"prefix"
    end

    it "#read" do
      mock(@store).read("prefix/cache_id/foo")
      @cache.read("foo")
    end

    it "#write" do
      mock(@store).write("prefix/cache_id/foo", "val")
      @cache.write("foo", "val")
      @cache.read('foo').should == "val"
    end

    it "#fetch" do
      block = Proc.new { "hi" }
      mock(@store).fetch("prefix/cache_id/foo", &block)
      @cache.fetch("foo", &block)
    end

    it "#delete" do
      mock(@store).delete("prefix/cache_id/foo")
      @cache.delete "foo"
    end

    it "#write_local" do
      @cache.write_local('a', 'foo')
      @cache.read("a").should == 'foo'
      mock.dont_allow(@store).write
      @cache.store.read("a").should == nil
    end
  end

  it "#reset" do
    pending "changed api"
    mock(Wagn::Cache).generate_cache_id.times(3).returns("cache_id1")
    Wagn::Cache.new
    @cache = Wagn::Cache[Card]
    @prefix = @cache.prefix
    #warn "prefix cid:#{@cache.cache_id_key}, p:#{@prefix.inspect}"

    @cache.prefix.should == @prefix

    @test_text = "some text"
    @cache.write("foo", @test_text)
    @cache.read("foo").should ==  @test_text

    # reset
    mock(Wagn::Cache).generate_cache_id.returns("cache_id2")
    @cache.reset
    #@cache.prefix.should =~ %r{_id2/$}
    @cache.store.read("prefix/cache_id").should == "cache_id2"
    @cache.read("foo").should be_nil

    cache2 = Wagn::Cache.new :store=>@store, :prefix=>"prefix"
    cache2.prefix.should == "prefix/cache_id2/"
  end

  describe "with file store" do
    before do
      pending "changed api"
      @cache = Wagn::Cache.new
      @store = @cache.store

      @store.clear if Pathname.new(cache_path).exist?
      #cache_path = cache_path + "/prefix"
      #p = Pathname.new(cache_path)
      #p.mkdir if !p.exist?
      #
      #root_dirs = Dir.entries(cache_path).reject{|f| ['.', '..'].include?(f)}
      #files_to_remove = root_dirs.collect{|f| File.join(cache_path, f)}
      #FileUtils.rm_r(files_to_remove)

      mock(Wagn::Cache).generate_cache_id.times(2).returns("cache_id1")
      @cache = Wagn::Cache.new :store=>@store, :prefix=>"prefix"
    end

    describe "#basic operations with special symbols" do
      it "should work" do
        @text = 'hello foo'
        @cache.write '%\\/*:?"<>|', @text
        @cache.read('%\\/*:?"<>|').should == @text
        @cache.reset true
        @cache.read('%\\/*:?"<>|').should_not be
      end
    end

    describe "#basic operations with non-latin symbols" do
      it "should work" do
        @text = 'hello foo'
        @cache.write('(汉语漢語 Hànyǔ; 华语華語 Huáyǔ; 中文 Zhōngwén', @text )
        @cache.write('русский', @text)
        @cache.reset
        @cache.read('русский').should == @text
        @cache.read('(汉语漢語 Hànyǔ; 华语華語 Huáyǔ; 中文 Zhōngwén').should == @text
        @cache.reset true
        @cache.read('(汉语漢語 Hànyǔ; 华语華語 Huáyǔ; 中文 Zhōngwén').should_not be
        @cache.read('русский').should_not be
        #cache3 = Wagn::Cache.new
        #cache3.read('(汉语漢語 Hànyǔ; 华语華語 Huáyǔ; 中文 Zhōngwén').name.should == 'a'
        #cache3.read('русский').name.should == 'B'
        @cache.reset
      end
    end

    describe "#tempfile" do
      # TODO
    end
  end
end
