#! no set module
class Bootstrap
  class Component
    def initialize context, *args, &block
      @context = context
      @content = ["".html_safe]
      @args = args
      @child_args = []
      @append = []
      @build_block = block
    end

    class << self
      def render format, *args, &block
        new(format, *args, &block).render
      end

      def add_div_method name, html_class, opts={}, &tag_block
        add_tag_method name, html_class, opts.merge(tag: :div), &tag_block
      end

      def add_tag_method name, html_class, tag_opts={}, &tag_block
        define_method name do |*args, &block|
          process_tag tag_opts[:tag] || name do
            content, opts, new_child_args = standardize_args args, &tag_block
            add_classes opts, html_class, tag_opts.delete(:optional_classes)
            if (attributes = tag_opts.delete(:attributes))
              opts.merge! attributes
            end

            content = with_child_args new_child_args do
              generate_content content,
                               tag_opts[:content_processor],
                               &block
            end

            [content, opts]
          end
        end
      end
    end

    def render
      @rendered = begin
        render_content
        @content[-1]
      end
    end

    def prepend &block
      tmp = @content.pop
      instance_exec &block
      @content << tmp
    end

    def insert &block
      instance_exec &block
    end

    def append &block
      @append[-1] << block
    end

    # def wrap
    #   tmp = @content.pop
    #   @content << yield(tmp)
    # end

    private

    def render_content
      # if @build_block.arity > 0
      instance_exec *@args, &@build_block
    end

    def generate_content content, processor, &block
      content = instance_exec &block if block.present?
      return content if !processor || !content.is_a?(Array)
      content.each { |item| send processor, item }
      ""
    end

    def with_child_args args
      @child_args << args if args.present?
      res = yield
      @child_args.pop if args.present?
      res
    end

    def add_content content
      @content[-1] << "\n#{content}".html_safe if content.present?
    end

    def process_tag tag_name
      @content.push "".html_safe
      @append << []
      content, opts = yield
      add_content content
      collected_content = @content.pop
      tag_name = opts.delete(:tag) if tag_name == :yield
      add_content content_tag(tag_name, collected_content, opts, false)
      @append.pop.each do |block|
        add_content instance_exec(&block)
      end
      ""
    end

    def standardize_args args, &block
      opts = args.last.is_a?(Hash) ? args.pop : {}
      items = ((args.one? && args.last.is_a?(String)) || args.last.is_a?(Array)) &&
              args.pop
      if block.present?
        opts, args = instance_exec opts, args, &block
        unless opts.is_a?(Hash)
          raise Card::Error, "first return value of a tag block has to be a hash"
        end
      end

      [items, opts, args]
    end

    def add_classes opts, html_class, optional_classes
      prepend_class opts, html_class if html_class
      Array.wrap(optional_classes).each do |k, v|
        prepend_class opts, v if opts.delete k
      end
    end

    include BasicTags
    include Delegate
  end
end
