module App
  # Every authenticated screen inherits from here: native shells only (soft
  # gate), a session required, Pundit available for authorization.
  class BaseController < ApplicationController
    include NativeOnly
    include Pundit::Authorization

    layout "application"
  end
end
