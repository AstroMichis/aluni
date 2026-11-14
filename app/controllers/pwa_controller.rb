# Web app manifest and the push-only service worker (no offline cache).
class PwaController < ApplicationController
  allow_unauthenticated_access
  skip_forgery_protection
  layout false

  def manifest
    render template: "pwa/manifest", formats: :json, content_type: "application/manifest+json"
  end

  def service_worker
    render template: "pwa/service-worker", formats: :js, content_type: "text/javascript"
  end
end
