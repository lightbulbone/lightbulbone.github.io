module Jekyll
  class SideNoteTag < Liquid::Block

    def initialize(tag_name, text, tokens)
      super
    end

    def render(context)
        note = super

        "<div class=\"panel panel-info\">
           <div class=\"panel-heading\">
             <h3 class=\"panel-title\">Side Note</h3>
           </div>
           <div class=\"panel-body\">
            #{note}
           </div>
         </div>
        "
    end
  end
end

Liquid::Template.register_tag('sidenote', Jekyll::SideNoteTag)
