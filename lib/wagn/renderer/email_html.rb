module Wagn
  class Renderer::EmailHtml < Renderer::HtmlRenderer
    def internal_url relative_path
      wagn_url relative_path
    end
  end
end
