# Per-request context. Jobs and services never read the request; whatever a
# job needs is set here in ApplicationJob or passed as a primitive argument.
class Current < ActiveSupport::CurrentAttributes
  attribute :session
  delegate :user, to: :session, allow_nil: true
end
