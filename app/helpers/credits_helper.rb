# Renders the credits registry (config/evidence/credits.yml) on the credits page.
module CreditsHelper
  URL = %r{https?://\S+?(?=[.,;]?(?:\s|\z))} # DOIs may hold parentheses: 10.1016/0022-1694(94)90110-4
  LICENCE_BADGES = { "unknown" => "warning", "terms" => "secondary", "copyright" => "secondary" }.freeze
  USED_IN_BADGES = { "app" => "success", "both" => "success", "backtest" => "info" }.freeze

  # A reference with its DOI and web addresses as links; the rest stays plain, escaped text.
  def credit_reference(text)
    parts = []
    rest = text.to_s
    while (match = URL.match(rest))
      parts << match.pre_match << link_to(match[0], match[0], rel: "noopener", target: "_blank")
      rest = match.post_match
    end
    safe_join(parts << rest)
  end

  def credit_licence_badge(kind) = "badge badge--#{LICENCE_BADGES.fetch(kind.to_s, 'accent')}"
  def credit_used_in_badge(used_in) = "badge badge--#{USED_IN_BADGES.fetch(used_in.to_s, 'info')}"
end
