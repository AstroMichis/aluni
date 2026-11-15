require "sidekiq/web"
require "sidekiq/cron/web"

Rails.application.routes.draw do
  # Health check: outside every scope, excluded from SSL redirects and host checks.
  get "up" => "rails/health#show", as: :rails_health_check

  # Native shells: path configuration (declared first so nothing swallows it)
  # and the universal/app links files, which also carry the passkey associations.
  get "configurations/v1/:platform", to: "configurations#show", as: :native_configuration, constraints: { platform: /ios|android/ }
  get ".well-known/apple-app-site-association", to: "app_links#apple", format: false
  get ".well-known/assetlinks.json", to: "app_links#android", format: false

  # PWA
  get "manifest.json", to: "pwa#manifest", format: false, as: :pwa_manifest
  get "service-worker.js", to: "pwa#service_worker", format: false, as: :pwa_service_worker

  # JSON API for native screens (session cookie + X-Aluni-Native header on writes).
  namespace :api do
    namespace :v1 do
      get "me", to: "me#show"
    end
  end

  # Inbound webhooks live outside the locale scope; each provider adds its
  # route here, wrapped in a Platform::Features constraint until it is turned on.
  namespace :webhooks do
  end

  # Sidekiq Web: operator host and basic auth, mounted only when credentials exist.
  if Platform::Features.sidekiq_web?
    Sidekiq::Web.use Rack::Auth::Basic do |username, password|
      ActiveSupport::SecurityUtils.secure_compare(username.to_s, Rails.configuration.x.sidekiq_web.username) &
        ActiveSupport::SecurityUtils.secure_compare(password.to_s, Rails.configuration.x.sidekiq_web.password)
    end
    constraints AdminHostConstraint.new do
      mount Sidekiq::Web => "/sidekiq"
    end
  end

  # Locale switcher, outside the scope so :new_locale never clashes with :locale.
  get "locale/:new_locale", to: "pages#set_locale", as: :set_locale, constraints: { new_locale: /en|es/ }

  scope "(:locale)", locale: /en|es/ do
    root "pages#home"

    # Passkey sign-in and sign-up (browsers and native shells; NATIVE_WEB_ACCESS=0 closes them to browsers).
    get    "sign_in",         to: "sessions#new",          as: :sign_in
    post   "sign_in/options", to: "sessions#options",      as: :sign_in_options
    post   "sign_in",         to: "sessions#create"
    delete "sign_out",        to: "sessions#destroy",      as: :sign_out
    get    "sign_up",         to: "registrations#new",     as: :sign_up
    post   "sign_up/options", to: "registrations#options", as: :sign_up_options
    post   "sign_up",         to: "registrations#create"

    resources :passkeys, only: %i[index create destroy] do
      post :options, on: :collection
    end

    # Authenticated area (native shells).
    namespace :app do
      root "home#show"
      # The onboarding chat: one page, Turbo Stream actions for every turn.
      resource :onboarding, only: :show, controller: "onboarding" do
        post :message
        post :confirm
        post :discard
        post :skip
        post :complete
        delete :reset
      end
      resources :device_tokens, only: :create
      delete "device_tokens", to: "device_tokens#destroy"
      resources :web_push_subscriptions, only: :create
    end
  end
end
