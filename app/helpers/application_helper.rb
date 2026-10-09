module ApplicationHelper
  JSON_TOKEN = /(&quot;(?:(?!&quot;).)*&quot;)(\s*:)?|\b(true|false|null)\b|(-?\d+(?:\.\d+)?)/

  # Pretty-prints a Hash/Array as syntax-highlighted JSON for docs.
  def highlight_json(obj)
    escaped = ERB::Util.html_escape(JSON.pretty_generate(obj))
    escaped.gsub(JSON_TOKEN) do
      if $1 then $2 ? %(<span class="tk-k">#{$1}</span>#{$2}) : %(<span class="tk-s">#{$1}</span>)
      elsif $3 then %(<span class="tk-n">#{$3}</span>)
      else %(<span class="tk-n">#{$4}</span>)
      end
    end.html_safe
  end

  # Flag of India (3:2): saffron, white, green, with the navy 24-spoke Ashoka Chakra. Drawn as an SVG so it
  # renders everywhere (emoji flags don't on Windows). Keep it undistorted and never put text over it.
  def india_flag(css = "h-4 w-6")
    spokes = (0...24).map do |i|
      a = i * 15 * Math::PI / 180
      %(<line x1="#{(18 + 1.1 * Math.cos(a)).round(2)}" y1="#{(12 + 1.1 * Math.sin(a)).round(2)}" x2="#{(18 + 3.3 * Math.cos(a)).round(2)}" y2="#{(12 + 3.3 * Math.sin(a)).round(2)}"/>)
    end.join
    <<~SVG.html_safe
      <svg viewBox="0 0 36 24" class="#{css} inline-block rounded-[2px] shadow-sm ring-1 ring-black/10" role="img" aria-label="Flag of India" xmlns="http://www.w3.org/2000/svg">
        <rect width="36" height="8" fill="#FF9933"/><rect y="8" width="36" height="8" fill="#FFFFFF"/><rect y="16" width="36" height="8" fill="#138808"/>
        <g stroke="#000080" stroke-width=".35" fill="none"><circle cx="18" cy="12" r="3.3" stroke-width=".5"/>#{spokes}</g>
      </svg>
    SVG
  end

  def method_badge(verb)
    tone = verb == "GET" ? "bg-teal/15 text-teal-deep" : "bg-blue/10 text-blue"
    content_tag(:span, verb, class: "rounded px-2 py-0.5 text-xs font-bold #{tone} data")
  end
end
