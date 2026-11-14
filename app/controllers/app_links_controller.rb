# The files that let links on aluni.us open the app and let the shells' web
# views use passkeys for aluni.us: iOS apple-app-site-association (applinks and
# webcredentials) and Android assetlinks.json (handle_all_urls and
# get_login_creds). Both answer 404 until the store accounts exist (credentials
# native_app.apple_team_id and native_app.android_cert_sha256, no defaults).
class AppLinksController < ActionController::Base
  def apple
    team_id = credential(:apple_team_id)
    return head(:not_found) if team_id.blank?

    app_id = "#{team_id}.#{NativeApp.bundle_id}"
    components = NativeApp.app_paths.flat_map { |path| [ { "/" => path }, { "/" => "/*#{path}" } ] }
    render json: {
      applinks: { details: [ { appIDs: [ app_id ], components: components } ] },
      webcredentials: { apps: [ app_id ] }
    }
  end

  def android
    fingerprint = credential(:android_cert_sha256)
    return head(:not_found) if fingerprint.blank?

    render json: [ {
      relation: [ "delegate_permission/common.handle_all_urls", "delegate_permission/common.get_login_creds" ],
      target: { namespace: "android_app", package_name: NativeApp.bundle_id, sha256_cert_fingerprints: Array(fingerprint) }
    } ]
  end

  private

  def credential(key) = Rails.application.credentials.dig(:native_app, key)
end
