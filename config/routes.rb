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

    # The main menu dial: a web preview for now, the app's first screen later.
    get "menu", to: "pages#menu", as: :menu
    # Section 1 of the menu, My fields: a preview on the sample farm (Fields::SampleFarm).
    scope "menu", as: "menu" do
      resources :fields, only: %i[index show new create] do
        collection do
          get :farm
          get :sources
          delete :preview, action: :reset
        end
      end
      patch "fields/:subject/readings/:datum", to: "field_readings#update", as: :field_reading

      # Sections 2 to 5, on the same farm preview.
      resource :crops, only: :show do
        get :rotation
        get :calendar
        patch :plan
      end
      resource :weather, only: :show, controller: "weather" do
        get :alerts
        patch :alerts, action: :update_alerts
      end
      resource :staff, only: :show, controller: "staff" do
        get :tasks
        get :roles
        post :members, action: :create_member
        patch "members/:id", action: :update_member, as: :member
        delete "members/:id", action: :destroy_member
        post :tasks, action: :create_task
        patch "tasks/:id", action: :update_task, as: :task
        delete "tasks/:id", action: :destroy_task
      end
      resource :reports, only: :show do
        get :harvest
        get :export
        get :download, constraints: { format: /json|csv/ }
      end
    end

    # Passkey sign-in and sign-up (native shells; NATIVE_WEB_ACCESS opens them to browsers).
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
      resources :device_tokens, only: :create
      delete "device_tokens", to: "device_tokens#destroy"
      resources :web_push_subscriptions, only: :create
    end
  end
end
