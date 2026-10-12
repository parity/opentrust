# Building blocks for the HTML emails. Email clients ignore stylesheets, so every style is inline, and the values come from
# the website's palette (app/assets/tailwind/application.css) so the emails look like the site.
module MailerHelper
  FONT = "Nunito, 'Trebuchet MS', Arial, Helvetica, sans-serif".freeze
  MONO = "'IBM Plex Mono', Menlo, Consolas, 'Courier New', monospace".freeze
  INK = "#151515".freeze
  SOFT = "#5A5C52".freeze
  LINE = "#D2D4C8".freeze
  PAPER = "#EEEFE9".freeze
  SUN = "#F0A020".freeze
  SUN_DEEP = "#B17816".freeze
  BLUE = "#1D4AFF".freeze

  def mail_logo_url = "#{root_url.chomp('/')}/email/opentrust-logo.png"

  def mail_h1(text)
    content_tag(:h1, text, style: "margin:0 0 16px; font-family:#{FONT}; font-size:28px; line-height:1.2; font-weight:800; color:#{INK};")
  end

  def mail_p(muted: false, &block)
    content_tag(:p, capture(&block), style: "margin:0 0 16px; font-family:#{FONT}; font-size:16px; line-height:1.6; color:#{muted ? SOFT : INK};")
  end

  # The website's marker-pen highlight, for the one phrase worth noticing.
  def mail_highlight(text)
    content_tag(:span, text, style: "background-color:#F8DFB0; padding:0 3px; border-radius:3px; font-weight:800;")
  end

  def mail_link(text, url)
    link_to(text, url, style: "color:#{BLUE}; text-decoration:underline;")
  end

  # A bulletproof button: the colour sits on the table cell, so it still shows when a client strips styles from the link.
  def mail_button(label, url)
    link = link_to(label, url, style: "display:inline-block; padding:13px 24px; font-family:#{FONT}; font-size:16px; font-weight:800; color:#{INK}; text-decoration:none;")
    cell = content_tag(:td, link, bgcolor: SUN, style: "border-radius:8px; border:1px solid #{SUN_DEEP}; border-bottom:4px solid #{SUN_DEEP};")
    content_tag(:table, content_tag(:tr, cell), role: "presentation", border: 0, cellpadding: 0, cellspacing: 0, style: "margin:24px 0;")
  end

  def mail_steps(*steps)
    items = steps.each_with_index.map do |step, i|
      content_tag(:tr) do
        safe_join([
          content_tag(:td, (i + 1).to_s, valign: "top", style: "width:32px; padding:0 0 12px; font-family:#{MONO}; font-size:15px; font-weight:500; color:#{SOFT};"),
          content_tag(:td, step, valign: "top", style: "padding:0 0 12px; font-family:#{FONT}; font-size:16px; line-height:1.5; color:#{INK};")
        ])
      end
    end
    content_tag(:table, safe_join(items), role: "presentation", border: 0, cellpadding: 0, cellspacing: 0, style: "margin:0 0 8px;")
  end
end
