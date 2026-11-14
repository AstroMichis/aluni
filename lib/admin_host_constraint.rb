# Restricts operator surfaces (Sidekiq Web) to the configured host(s), ADMIN_HOST.
class AdminHostConstraint
  def initialize(hosts = nil)
    @hosts = hosts && Array(hosts).map { |h| h.to_s.downcase }
  end

  def matches?(request)
    (@hosts || ADMIN_HOSTS).include?(request.host.to_s.downcase)
  end
end
