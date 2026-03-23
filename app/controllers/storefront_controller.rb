# frozen_string_literal: true

# Lightweight customer-facing storefront for HSI connector testing.
# Mirrors the interface our GenericConnector expects:
#   GET  /login          — login form
#   POST /login          — authenticate
#   GET  /catalog        — paginated product listing
#   GET  /products/:id   — product detail with add-to-cart
#   POST /cart           — add item to cart
#   DELETE /cart/:sku    — remove item
#   GET  /cart           — view cart
#   GET  /checkout       — checkout form
#   POST /checkout       — submit order
#   GET  /order/confirmation — confirmation page
class StorefrontController < ApplicationController
  layout "storefront"
  before_action :require_auth!, except: %i[login do_login]

  # ── Auth ──────────────────────────────────────────────────────
  def login
    render :login
  end

  def do_login
    email    = params[:email].to_s.strip
    password = params[:password].to_s

    user = Spree::User.find_by(email: email)
    if user&.valid_password?(password)
      session[:user_id] = user.id
      redirect_to "/catalog"
    else
      flash.now[:error] = "Invalid email or password"
      render :login, status: :unprocessable_entity
    end
  end

  def logout
    session.delete(:user_id)
    redirect_to "/login"
  end

  # ── Catalog ───────────────────────────────────────────────────
  def catalog
    @page = [params[:page].to_i, 1].max
    per_page = 10
    store = Spree::Store.default
    @products = Spree::Product
      .joins(:stores).where(spree_stores: { id: store.id })
      .where(status: "active")
      .includes(master: :prices)
      .order(:name)
      .offset((@page - 1) * per_page)
      .limit(per_page + 1) # fetch one extra to detect next page

    @has_next = @products.size > per_page
    @products = @products.first(per_page)
  end

  # ── Product Detail ────────────────────────────────────────────
  def show_product
    @product = find_product(params[:id])
    head :not_found unless @product
  end

  # ── Cart ──────────────────────────────────────────────────────
  def add_to_cart
    sku = params[:sku].to_s.strip
    qty = [params[:qty].to_i, 1].max

    variant = Spree::Variant.find_by(sku: sku)
    unless variant
      flash[:error] = "Product not found"
      redirect_to "/catalog" and return
    end

    if variant.stock_items.sum(:count_on_hand) <= 0
      render plain: "Out of stock", status: :unprocessable_entity and return
    end

    cart[sku] = (cart[sku] || 0) + qty
    redirect_to "/cart"
  end

  def remove_from_cart
    cart.delete(params[:sku])
    redirect_to "/cart"
  end

  def view_cart
    @cart_items = build_cart_items
    @total_cents = @cart_items.sum { |i| i[:price_cents] * i[:qty] }
  end

  # ── Checkout ──────────────────────────────────────────────────
  def checkout
    @cart_items = build_cart_items
    @total_cents = @cart_items.sum { |i| i[:price_cents] * i[:qty] }
  end

  def submit_checkout
    if cart.empty?
      redirect_to "/cart" and return
    end

    session[:last_order_number] = "ORD-SPREE-#{Time.current.strftime('%H%M%S%L')}"
    session[:cart] = {}
    redirect_to "/order/confirmation"
  end

  def confirmation
    @order_number = session[:last_order_number] || "ORD-SPREE-001"
  end

  private

  def current_user
    @current_user ||= Spree::User.find_by(id: session[:user_id]) if session[:user_id]
  end
  helper_method :current_user

  def require_auth!
    return if current_user

    redirect_to "/login"
  end

  def cart
    session[:cart] ||= {}
  end

  # Resolve product by ID or variant SKU
  def find_product(id_or_sku)
    Spree::Product.find_by(id: id_or_sku) ||
      Spree::Variant.find_by(sku: id_or_sku)&.product
  end

  # Build cart items from session cart hash
  def build_cart_items
    cart.filter_map do |sku, qty|
      variant = Spree::Variant.includes(:product, :prices).find_by(sku: sku)
      next unless variant

      price_cents = (variant.price_in("CAD")&.amount.to_f * 100).round
      {
        variant: variant,
        product: variant.product,
        sku: sku,
        qty: qty,
        price_cents: price_cents,
        label: variant.options_text.presence || variant.sku
      }
    end
  end
end
