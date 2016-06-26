module Jekyll
  class FigureTag < Liquid::Tag

    def initialize(tag_name, markup, tokens)
      super
      @attrs = {}

      markup.scan(Liquid::TagAttributes) do |key, value|
        @attrs[key] = value.gsub(/"/,"")
      end
    end

    def render(context)
      "<div class=\"container\" style=\"margin-top: 10px; margin-bottom: 10px\">
        <div class=\"row\">
         <div class=\"col-lg-10 col-lg-offset-1\">
          <figure>
           <img src=\"#{@attrs['img']}\" class=\"img-responsive\" />
           <div class=\"row\"><div class=\"col-lg-8 col-lg-offset-2\">
           <figcaption>Figure #{@attrs['fnum']}: #{@attrs['caption']}</figcaption>
           </div></div>
          </figure>
         </div>
        </div>
       </div>
      "
    end
  end
end

Liquid::Template.register_tag('figure', Jekyll::FigureTag)
