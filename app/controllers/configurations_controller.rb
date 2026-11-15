# GET /configurations/v1/:platform (ios | android): the tabs, colours and path
# rules the native shells merge over their bundled path_configuration.json.
# Fetched before sign-in, so no authentication and no native gate.
class ConfigurationsController < ApplicationController
  allow_unauthenticated_access
  skip_before_action :verify_authenticity_token

  def show
    platform = params[:platform].to_sym
    locale = I18n.locale

    render json: {
      settings: {
        brand: {
          name: NativeApp.name,
          tint: NativeApp.colors["tint"],
          background: NativeApp.colors["background"],
          home_path: "/#{locale}#{NativeApp.home_path}",
          sign_in_path: "/#{locale}#{NativeApp.sign_in_path}"
        },
        tabs: NativeApp.tabs.map do |tab|
          { key: tab["key"], title: t("native_app.tabs.#{tab['key']}"), url: "/#{locale}#{tab['path']}",
            icon: platform == :ios ? tab["ios_icon"] : tab["android_icon"] }
        end
      },
      rules: rules
    }
  end

  private

  # Hotwire Native path configuration rules, written for paths with or without
  # a locale prefix. Modal patterns and the native-screen mapping (view_controller
  # on iOS, uri: hotwire://fragment/<name> on Android) go here as screens appear.
  def rules
    lp = "(/(en|es))?"
    [
      { patterns: [ ".*" ], properties: { context: "default", pull_to_refresh_enabled: true, animated: true } },
      { patterns: [ "#{lp}/(sign_in|sign_up)$" ], properties: { context: "default", presentation: "replace", pull_to_refresh_enabled: false } },
      { patterns: [ "#{lp}/sign_in/(code|link)(/.*)?$" ], properties: { context: "default", pull_to_refresh_enabled: false } },
      { patterns: [ "#{lp}/sign_out$" ], properties: { presentation: "clear_all" } },
      { patterns: [ "/new$", "/edit$" ], properties: { context: "modal", modal_style: "large", modal_dismiss_gesture_enabled: false, pull_to_refresh_enabled: false } },
      { patterns: [ "#{lp}/passkeys$" ], properties: { pull_to_refresh_enabled: false } }
    ]
  end
end
