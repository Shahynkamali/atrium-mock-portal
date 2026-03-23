require 'sidekiq/web'

Rails.application.routes.draw do
  Spree::Core::Engine.add_routes do
    # Admin authentication
    devise_for(
      Spree.admin_user_class.model_name.singular_route_key,
      class_name: Spree.admin_user_class.to_s,
      controllers: {
        sessions: 'spree/admin/user_sessions',
        passwords: 'spree/admin/user_passwords'
      },
      skip: :registrations,
      path: :admin_user,
      router_name: :spree
    )
  end
  # This line mounts Spree's routes at the root of your application.
  # This means, any requests to URLs such as /products, will go to
  # Spree::ProductsController.
  # If you would like to change where this engine is mounted, simply change the
  # :at option to something different.
  #
  # We ask that you don't use the :as option here, as Spree relies on it being
  # the default of "spree".
  mount Spree::Core::Engine, at: '/'
  devise_for :admin_users, class_name: "Spree::AdminUser"
  devise_for :users, class_name: "Spree::User"

  # Sidekiq Web UI
  authenticate Spree.admin_user_class.model_name.singular_route_key.to_sym, ->(admin_user) { admin_user.spree_admin? } do
    mount Sidekiq::Web => "/sidekiq" # access it at http://localhost:3000/sidekiq
  end

  # ── Storefront (customer-facing portal for HSI connector testing) ──
  get    "login"              => "storefront#login",           as: :login
  post   "login"              => "storefront#do_login"
  get    "logout"             => "storefront#logout",          as: :logout
  get    "catalog"            => "storefront#catalog",         as: :catalog
  get    "products/:id"       => "storefront#show_product",    as: :product
  post   "cart"               => "storefront#add_to_cart"
  delete "cart/:sku"          => "storefront#remove_from_cart"
  get    "cart"               => "storefront#view_cart",       as: :cart
  get    "checkout"           => "storefront#checkout"
  post   "checkout"           => "storefront#submit_checkout"
  get    "order/confirmation" => "storefront#confirmation",    as: :confirmation

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  root to: redirect('/catalog')
end
