Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      post "lookups", to: "lookups#create"
      post "lookups/batch", to: "lookups#batch"
      post "reports", to: "reports#create"
      post "reports/batch", to: "reports#batch"
      delete "reports", to: "reports#destroy"
      post "phone_hash/check", to: "phone_hash#check"
      get "reason_codes", to: "reason_codes#index"
      get "me", to: "me#show"
    end
  end

  root "pages#home"
  get "faq", to: "pages#faq"
  get "privacy", to: "pages#privacy"
  get "terms", to: "pages#terms"
  get "docs", to: "pages#docs"
  get "libraries", to: "pages#libraries"

  get "register", to: "registrations#new"
  post "register", to: "registrations#create"
  get "login", to: "sessions#new"
  post "login", to: "sessions#create"
  delete "logout", to: "sessions#destroy"
  get "verify-email", to: "email_verifications#show"
  post "verify-email", to: "email_verifications#create"
  post "verify-email/resend", to: "email_verifications#resend"

  namespace :portal do
    root "dashboard#show"
    resources :api_keys, only: %i[index create destroy]
    resources :reports, only: %i[index new create]
    get "ledger", to: "ledger#index"
  end

  namespace :admin do
    root "merchants#index"
    get "login", to: "sessions#new"
    post "login", to: "sessions#create"
    delete "logout", to: "sessions#destroy"
    resources :merchants, only: :index do
      member do
        post :approve
        post :reject
        post :suspend
        post :adjust
      end
    end
    resources :reports, only: :index do
      member { post :remove }
    end
    resources :audit_logs, only: :index
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
