# frozen_string_literal: true

# ============================================================
# db/seeds.rb — Atrium Mock Supplier Portal
# Hotel supply catalog for HSI connector testing
# ============================================================

# Step 1: Core Spree infrastructure (zones, countries, currencies, admin user)
Spree::Core::Engine.load_seed if defined?(Spree::Core)

# Suppress Spree event callbacks during seeding (they enqueue Sidekiq jobs
# that aren't needed during build and slow down the seed significantly).
Spree::Product.skip_callback(:commit, :after, :fire_event) rescue nil
Spree::Variant.skip_callback(:commit, :after, :fire_event) rescue nil

puts "\n== Seeding hotel supply catalog =="

# ============================================================
# Store
# ============================================================
store_attrs = {
  name:                 "Atrium Mock Supplier Portal",
  url:                  ENV.fetch("RENDER_EXTERNAL_URL", "localhost:3000"),
  mail_from_address:    "orders@mock-supplier.dev",
  default_currency:     "CAD",
  default_locale:       "en",
  supported_currencies: "CAD",
  supported_locales:    "en",
  default:              true
}
store = Spree::Store.find_by(code: "atrium-mock") || Spree::Store.first
if store
  store.update!(store_attrs.merge(code: "atrium-mock"))
else
  store = Spree::Store.create!(store_attrs.merge(code: "atrium-mock"))
end

# ============================================================
# Infrastructure
# ============================================================
shipping_category = Spree::ShippingCategory.find_or_create_by!(name: "Default")
tax_category      = Spree::TaxCategory.find_or_create_by!(name: "Default")

# ============================================================
# Taxonomy / Categories
# ============================================================
taxonomy = Spree::Taxonomy.find_or_create_by!(name: "Categories", store: store)
root     = taxonomy.root

def taxon(parent, name)
  parent.children.find_or_create_by!(name: name, taxonomy: parent.taxonomy)
end

housekeeping = taxon(root,         "Housekeeping")
bath         = taxon(housekeeping, "Bath Amenities")
cleaning     = taxon(housekeeping, "Cleaning Supplies")
linens       = taxon(housekeeping, "Linens & Laundry")

fnb          = taxon(root,  "F&B")
beverages    = taxon(fnb,   "Beverages")
kitchen      = taxon(fnb,   "Kitchen Supplies")

maintenance  = taxon(root,        "Maintenance")
safety_ppe   = taxon(maintenance, "Safety & PPE")
janitorial   = taxon(maintenance, "Janitorial")

puts "  Taxons: #{Spree::Taxon.count} created"

# ============================================================
# Option Types
# ============================================================
size_opt  = Spree::OptionType.find_or_create_by!(name: "size",  presentation: "Size")
count_opt = Spree::OptionType.find_or_create_by!(name: "count", presentation: "Count")
grade_opt = Spree::OptionType.find_or_create_by!(name: "grade", presentation: "Grade")

def option_value(opt_type, val)
  Spree::OptionValue.find_or_create_by!(
    name:         val.downcase.tr(" /", "_"),
    presentation: val,
    option_type:  opt_type
  )
end

# ============================================================
# Helper
# ============================================================
def create_product(name:, slug:, sku:, description:, price:, taxon:,
                   shipping_category:, tax_category:, store:,
                   option_type: nil, variants: [])

  if Spree::Product.find_by(slug: slug)
    print "."
    return
  end

  product = Spree::Product.create!(
    name:              name,
    slug:              slug,
    description:       description,
    shipping_category: shipping_category,
    tax_category:      tax_category,
    available_on:      Time.current,
    status:            "active"
  )
  product.taxons << taxon
  product.stores << store

  # Master variant — always required
  product.master.sku = sku
  product.master.price = price
  product.master.save!
  product.master.stock_items.each { |si| si.set_count_on_hand(500) }

  if variants.any? && option_type
    product.option_types << option_type

    variants.each do |v|
      ov = option_value(option_type, v[:label])
      var = product.variants.create!(
        sku:          v[:sku],
        track_inventory: true
      )
      var.option_values << ov
      var.price = v[:price]
      var.save!
      var.stock_items.each { |si| si.set_count_on_hand(v.fetch(:stock, 500)) }
    end
  end

  print "."
end

# ============================================================
# HOUSEKEEPING — Bath Amenities
# ============================================================
puts "\n  Bath Amenities..."

create_product(
  name: "Hotel Shampoo", slug: "hsk-shampoo", sku: "HSK-SHMP",
  description: "Hotel-grade shampoo. Gentle formula, travel size and full size available.",
  price: 1.25, taxon: bath,
  shipping_category: shipping_category, tax_category: tax_category, store: store,
  option_type: size_opt,
  variants: [
    { sku: "HSK-SHMP-50ML",  label: "50ml",  price: 1.25,  stock: 2000 },
    { sku: "HSK-SHMP-100ML", label: "100ml", price: 2.15,  stock: 1000 },
    { sku: "HSK-SHMP-500ML", label: "500ml", price: 7.99,  stock: 500  },
  ]
)

create_product(
  name: "Hotel Conditioner", slug: "hsk-conditioner", sku: "HSK-COND",
  description: "Moisturising conditioner. Pairs with hotel shampoo.",
  price: 1.25, taxon: bath,
  shipping_category: shipping_category, tax_category: tax_category, store: store,
  option_type: size_opt,
  variants: [
    { sku: "HSK-COND-50ML",  label: "50ml",  price: 1.25,  stock: 2000 },
    { sku: "HSK-COND-100ML", label: "100ml", price: 2.15,  stock: 1000 },
    { sku: "HSK-COND-500ML", label: "500ml", price: 7.99,  stock: 500  },
  ]
)

create_product(
  name: "Body Wash", slug: "hsk-body-wash", sku: "HSK-BDYWSH",
  description: "Hotel body wash with fresh scent. Biodegradable formula.",
  price: 1.35, taxon: bath,
  shipping_category: shipping_category, tax_category: tax_category, store: store,
  option_type: size_opt,
  variants: [
    { sku: "HSK-BDYWSH-50ML",  label: "50ml",  price: 1.35, stock: 2000 },
    { sku: "HSK-BDYWSH-100ML", label: "100ml", price: 2.45, stock: 1000 },
    { sku: "HSK-BDYWSH-500ML", label: "500ml", price: 8.99, stock: 500  },
  ]
)

create_product(
  name: "Hand Soap Bar", slug: "hsk-hand-soap-bar", sku: "HSK-SOAP-BAR",
  description: "Individually wrapped hotel soap bar. 20g each.",
  price: 0.55, taxon: bath,
  shipping_category: shipping_category, tax_category: tax_category, store: store,
  option_type: count_opt,
  variants: [
    { sku: "HSK-SOAP-BAR-100CT", label: "100-pack", price: 54.99,  stock: 200 },
    { sku: "HSK-SOAP-BAR-500CT", label: "500-pack", price: 249.99, stock: 50  },
  ]
)

create_product(
  name: "Liquid Hand Soap Pump", slug: "hsk-hand-soap-pump", sku: "HSK-SOAP-PUMP",
  description: "Refillable pump dispenser hand soap for hotel bathrooms.",
  price: 3.99, taxon: bath,
  shipping_category: shipping_category, tax_category: tax_category, store: store,
  option_type: size_opt,
  variants: [
    { sku: "HSK-SOAP-PUMP-250ML", label: "250ml", price: 3.99,  stock: 500 },
    { sku: "HSK-SOAP-PUMP-1L",    label: "1L",    price: 11.99, stock: 300 },
  ]
)

create_product(
  name: "Facial Tissue Box", slug: "hsk-facial-tissue", sku: "HSK-TISSUE",
  description: "2-ply facial tissue. 200 sheets per box. Suitable for guest rooms.",
  price: 2.49, taxon: bath,
  shipping_category: shipping_category, tax_category: tax_category, store: store,
  option_type: count_opt,
  variants: [
    { sku: "HSK-TISSUE-1BOX",   label: "Single box",  price: 2.49,  stock: 1000 },
    { sku: "HSK-TISSUE-24CASE", label: "Case (24 boxes)", price: 54.99, stock: 100  },
  ]
)

create_product(
  name: "Toilet Paper Roll", slug: "hsk-toilet-paper", sku: "HSK-TP",
  description: "2-ply toilet paper, 400 sheets per roll. Septic-safe.",
  price: 0.79, taxon: bath,
  shipping_category: shipping_category, tax_category: tax_category, store: store,
  option_type: count_opt,
  variants: [
    { sku: "HSK-TP-48CT",  label: "Case (48 rolls)", price: 34.99,  stock: 200 },
    { sku: "HSK-TP-96CT",  label: "Case (96 rolls)", price: 64.99,  stock: 100 },
  ]
)

# ============================================================
# HOUSEKEEPING — Cleaning Supplies
# ============================================================
puts "\n  Cleaning Supplies..."

create_product(
  name: "All-Purpose Cleaner", slug: "hsk-apc", sku: "HSK-APC",
  description: "Commercial-grade all-purpose surface cleaner. Food-safe.",
  price: 4.99, taxon: cleaning,
  shipping_category: shipping_category, tax_category: tax_category, store: store,
  option_type: size_opt,
  variants: [
    { sku: "HSK-APC-500ML", label: "500ml", price: 4.99,  stock: 500 },
    { sku: "HSK-APC-1L",    label: "1L",    price: 8.49,  stock: 300 },
    { sku: "HSK-APC-4L",    label: "4L",    price: 24.99, stock: 100 },
  ]
)

create_product(
  name: "Glass & Window Cleaner", slug: "hsk-glass-cleaner", sku: "HSK-GLS",
  description: "Streak-free glass and mirror cleaner. Fast-drying formula.",
  price: 5.49, taxon: cleaning,
  shipping_category: shipping_category, tax_category: tax_category, store: store,
  option_type: size_opt,
  variants: [
    { sku: "HSK-GLS-500ML", label: "500ml", price: 5.49,  stock: 500 },
    { sku: "HSK-GLS-1L",    label: "1L",    price: 9.49,  stock: 300 },
  ]
)

create_product(
  name: "Bathroom Disinfectant Spray", slug: "hsk-disinfectant", sku: "HSK-DISF",
  description: "Kills 99.9% of bacteria and viruses. Safe on all bathroom surfaces.",
  price: 6.99, taxon: cleaning,
  shipping_category: shipping_category, tax_category: tax_category, store: store,
  option_type: size_opt,
  variants: [
    { sku: "HSK-DISF-500ML", label: "500ml", price: 6.99,  stock: 500 },
    { sku: "HSK-DISF-1L",    label: "1L",    price: 11.99, stock: 300 },
  ]
)

create_product(
  name: "Floor Cleaner Concentrate", slug: "hsk-floor-cleaner", sku: "HSK-FLR",
  description: "Concentrated floor cleaning solution. Dilute 1:10 with water.",
  price: 12.99, taxon: cleaning,
  shipping_category: shipping_category, tax_category: tax_category, store: store,
  option_type: size_opt,
  variants: [
    { sku: "HSK-FLR-1L", label: "1L",  price: 12.99, stock: 300 },
    { sku: "HSK-FLR-4L", label: "4L",  price: 39.99, stock: 100 },
  ]
)

create_product(
  name: "Microfiber Cleaning Cloths", slug: "hsk-microfiber", sku: "HSK-MFC",
  description: "High-absorbency microfiber cloths. Colour-coded for hygiene compliance.",
  price: 14.99, taxon: cleaning,
  shipping_category: shipping_category, tax_category: tax_category, store: store,
  option_type: count_opt,
  variants: [
    { sku: "HSK-MFC-10PK", label: "10-pack", price: 14.99, stock: 300 },
    { sku: "HSK-MFC-20PK", label: "20-pack", price: 26.99, stock: 150 },
  ]
)

create_product(
  name: "Scrubbing Sponge", slug: "hsk-sponge", sku: "HSK-SPG",
  description: "Dual-sided scrubbing sponge. Non-scratch side safe for non-stick surfaces.",
  price: 7.99, taxon: cleaning,
  shipping_category: shipping_category, tax_category: tax_category, store: store,
  option_type: count_opt,
  variants: [
    { sku: "HSK-SPG-6PK",  label: "6-pack",  price: 7.99,  stock: 500 },
    { sku: "HSK-SPG-12PK", label: "12-pack", price: 13.99, stock: 300 },
  ]
)

# ============================================================
# HOUSEKEEPING — Linens & Laundry
# ============================================================
puts "\n  Linens..."

create_product(
  name: "Bath Towel", slug: "hsk-bath-towel", sku: "HSK-TOWEL-BATH",
  description: "550 GSM 100% cotton hotel bath towel. Washable up to 90°C.",
  price: 12.99, taxon: linens,
  shipping_category: shipping_category, tax_category: tax_category, store: store,
  option_type: grade_opt,
  variants: [
    { sku: "HSK-TOWEL-BATH-STD",  label: "Standard",  price: 12.99, stock: 500 },
    { sku: "HSK-TOWEL-BATH-LUX",  label: "Luxury",    price: 18.99, stock: 300 },
  ]
)

create_product(
  name: "Hand Towel", slug: "hsk-hand-towel", sku: "HSK-TOWEL-HAND",
  description: "Hotel hand towel, 40x60cm. Matches bath towel range.",
  price: 6.99, taxon: linens,
  shipping_category: shipping_category, tax_category: tax_category, store: store,
  option_type: grade_opt,
  variants: [
    { sku: "HSK-TOWEL-HAND-STD", label: "Standard", price: 6.99,  stock: 500 },
    { sku: "HSK-TOWEL-HAND-LUX", label: "Luxury",   price: 9.99,  stock: 300 },
  ]
)

create_product(
  name: "Washcloth", slug: "hsk-washcloth", sku: "HSK-WCLOTH",
  description: "30x30cm hotel washcloth. Sold in cases of 12.",
  price: 2.49, taxon: linens,
  shipping_category: shipping_category, tax_category: tax_category, store: store,
  option_type: count_opt,
  variants: [
    { sku: "HSK-WCLOTH-12PK", label: "12-pack", price: 27.99, stock: 300 },
    { sku: "HSK-WCLOTH-24PK", label: "24-pack", price: 49.99, stock: 150 },
  ]
)

create_product(
  name: "Commercial Laundry Detergent", slug: "hsk-laundry-det", sku: "HSK-LDRY",
  description: "High-efficiency laundry detergent for commercial washers. Low-foam formula.",
  price: 29.99, taxon: linens,
  shipping_category: shipping_category, tax_category: tax_category, store: store,
  option_type: size_opt,
  variants: [
    { sku: "HSK-LDRY-5KG",  label: "5kg",  price: 29.99, stock: 100 },
    { sku: "HSK-LDRY-10KG", label: "10kg", price: 54.99, stock: 50  },
  ]
)

# ============================================================
# F&B — Beverages
# ============================================================
puts "\n  Beverages..."

create_product(
  name: "Ground Coffee — Medium Roast", slug: "fb-coffee-medium", sku: "FB-COFFEE-MED",
  description: "100% Arabica medium roast ground coffee. Suitable for all commercial brewers.",
  price: 14.99, taxon: beverages,
  shipping_category: shipping_category, tax_category: tax_category, store: store,
  option_type: size_opt,
  variants: [
    { sku: "FB-COFFEE-MED-250G", label: "250g", price: 14.99, stock: 200 },
    { sku: "FB-COFFEE-MED-1KG",  label: "1kg",  price: 49.99, stock: 100 },
  ]
)

create_product(
  name: "Tea Bags — Assorted", slug: "fb-tea-bags", sku: "FB-TEA",
  description: "Individually wrapped assorted tea bags (black, green, chamomile, mint).",
  price: 12.99, taxon: beverages,
  shipping_category: shipping_category, tax_category: tax_category, store: store,
  option_type: count_opt,
  variants: [
    { sku: "FB-TEA-50CT",  label: "50-count",  price: 12.99, stock: 300 },
    { sku: "FB-TEA-100CT", label: "100-count", price: 22.99, stock: 200 },
    { sku: "FB-TEA-200CT", label: "200-count", price: 39.99, stock: 100 },
  ]
)

create_product(
  name: "Bottled Water", slug: "fb-water", sku: "FB-WATER",
  description: "Spring water. Suitable for in-room placement and F&B service.",
  price: 18.99, taxon: beverages,
  shipping_category: shipping_category, tax_category: tax_category, store: store,
  option_type: size_opt,
  variants: [
    { sku: "FB-WATER-500ML-24CT", label: "500ml (case/24)", price: 18.99, stock: 200 },
    { sku: "FB-WATER-1L-12CT",    label: "1L (case/12)",    price: 17.99, stock: 150 },
  ]
)

create_product(
  name: "Sugar Packets", slug: "fb-sugar", sku: "FB-SUGAR",
  description: "White sugar portion packs, 5g each. Suitable for in-room tea/coffee service.",
  price: 9.99, taxon: beverages,
  shipping_category: shipping_category, tax_category: tax_category, store: store,
  option_type: count_opt,
  variants: [
    { sku: "FB-SUGAR-200CT", label: "200-count", price: 9.99,  stock: 300 },
    { sku: "FB-SUGAR-500CT", label: "500-count", price: 21.99, stock: 150 },
  ]
)

create_product(
  name: "Coffee Creamer Cups", slug: "fb-creamer", sku: "FB-CREAMER",
  description: "Non-dairy individual creamer cups, 10ml each. No refrigeration required.",
  price: 14.99, taxon: beverages,
  shipping_category: shipping_category, tax_category: tax_category, store: store,
  option_type: count_opt,
  variants: [
    { sku: "FB-CREAMER-100CT", label: "100-count", price: 14.99, stock: 300 },
    { sku: "FB-CREAMER-200CT", label: "200-count", price: 26.99, stock: 150 },
  ]
)

# ============================================================
# F&B — Kitchen Supplies
# ============================================================
puts "\n  Kitchen Supplies..."

create_product(
  name: "Disposable Cups", slug: "fb-disposable-cups", sku: "FB-CUPS",
  description: "Compostable paper cups for in-room coffee service.",
  price: 8.99, taxon: kitchen,
  shipping_category: shipping_category, tax_category: tax_category, store: store,
  option_type: size_opt,
  variants: [
    { sku: "FB-CUPS-8OZ-50CT",  label: "8oz (50-pack)",  price: 8.99,  stock: 300 },
    { sku: "FB-CUPS-12OZ-50CT", label: "12oz (50-pack)", price: 10.99, stock: 300 },
  ]
)

create_product(
  name: "Paper Plates", slug: "fb-paper-plates", sku: "FB-PLATES",
  description: "Sturdy 9-inch paper plates. Grease-resistant coating.",
  price: 11.99, taxon: kitchen,
  shipping_category: shipping_category, tax_category: tax_category, store: store,
  option_type: count_opt,
  variants: [
    { sku: "FB-PLATES-50CT",  label: "50-count",  price: 11.99, stock: 300 },
    { sku: "FB-PLATES-100CT", label: "100-count", price: 20.99, stock: 150 },
  ]
)

create_product(
  name: "Cutlery Kit (Individually Wrapped)", slug: "fb-cutlery", sku: "FB-CUTLERY",
  description: "Wrapped fork + knife + spoon + napkin kit. For room service and takeaway.",
  price: 19.99, taxon: kitchen,
  shipping_category: shipping_category, tax_category: tax_category, store: store,
  option_type: count_opt,
  variants: [
    { sku: "FB-CUTLERY-50CT",  label: "50-count",  price: 19.99, stock: 200 },
    { sku: "FB-CUTLERY-100CT", label: "100-count", price: 36.99, stock: 100 },
  ]
)

# ============================================================
# MAINTENANCE — Safety & PPE
# ============================================================
puts "\n  Safety & PPE..."

create_product(
  name: "Disposable Latex Gloves", slug: "mnt-gloves-latex", sku: "MNT-GLOVES-LTX",
  description: "Powder-free disposable latex gloves, box of 100. For housekeeping use.",
  price: 12.99, taxon: safety_ppe,
  shipping_category: shipping_category, tax_category: tax_category, store: store,
  option_type: size_opt,
  variants: [
    { sku: "MNT-GLOVES-LTX-S",  label: "Small",       price: 12.99, stock: 200 },
    { sku: "MNT-GLOVES-LTX-M",  label: "Medium",      price: 12.99, stock: 300 },
    { sku: "MNT-GLOVES-LTX-L",  label: "Large",       price: 12.99, stock: 300 },
    { sku: "MNT-GLOVES-LTX-XL", label: "Extra Large", price: 12.99, stock: 100 },
  ]
)

create_product(
  name: "First Aid Kit", slug: "mnt-first-aid-kit", sku: "MNT-FAK",
  description: "WSIB-compliant first aid kit for hotel departments. Includes bandages, antiseptic, gloves.",
  price: 34.99, taxon: safety_ppe,
  shipping_category: shipping_category, tax_category: tax_category, store: store,
  option_type: grade_opt,
  variants: [
    { sku: "MNT-FAK-SM",  label: "Small (10 person)",    price: 34.99, stock: 100 },
    { sku: "MNT-FAK-STD", label: "Standard (25 person)", price: 59.99, stock: 50  },
    { sku: "MNT-FAK-LRG", label: "Large (50 person)",    price: 89.99, stock: 25  },
  ]
)

create_product(
  name: "Safety Caution Wet Floor Sign", slug: "mnt-wet-floor-sign", sku: "MNT-WFS",
  description: "Bilingual (EN/FR) foldable wet floor caution sign. Yellow HDPE.",
  price: 14.99, taxon: safety_ppe,
  shipping_category: shipping_category, tax_category: tax_category, store: store
)

# ============================================================
# MAINTENANCE — Janitorial
# ============================================================
puts "\n  Janitorial..."

create_product(
  name: "Garbage Bags", slug: "mnt-garbage-bags", sku: "MNT-GBAGS",
  description: "Heavy-duty polyethylene garbage bags. Suitable for hotel room waste bins.",
  price: 14.99, taxon: janitorial,
  shipping_category: shipping_category, tax_category: tax_category, store: store,
  option_type: size_opt,
  variants: [
    { sku: "MNT-GBAGS-30L-50CT",  label: "30L (50-pack)",  price: 14.99, stock: 300 },
    { sku: "MNT-GBAGS-60L-50CT",  label: "60L (50-pack)",  price: 19.99, stock: 200 },
    { sku: "MNT-GBAGS-120L-25CT", label: "120L (25-pack)", price: 22.99, stock: 100 },
  ]
)

create_product(
  name: "Mop Head Replacement", slug: "mnt-mop-head", sku: "MNT-MOPHEAD",
  description: "Commercial looped-end wet mop head. Universal bracket fit. 400g.",
  price: 9.99, taxon: janitorial,
  shipping_category: shipping_category, tax_category: tax_category, store: store,
  option_type: count_opt,
  variants: [
    { sku: "MNT-MOPHEAD-1PK", label: "Single",  price: 9.99,  stock: 300 },
    { sku: "MNT-MOPHEAD-6PK", label: "6-pack",  price: 52.99, stock: 100 },
  ]
)

create_product(
  name: "Mop Bucket with Wringer", slug: "mnt-mop-bucket", sku: "MNT-MOPBKT",
  description: "25L institutional mop bucket with side-press wringer. Heavy-gauge plastic.",
  price: 49.99, taxon: janitorial,
  shipping_category: shipping_category, tax_category: tax_category, store: store
)

create_product(
  name: "Cleaning Cart / Trolley", slug: "mnt-cleaning-cart", sku: "MNT-CART",
  description: "Hotel housekeeping cart. Adjustable shelves, linen bag hooks, vinyl liner.",
  price: 299.99, taxon: janitorial,
  shipping_category: shipping_category, tax_category: tax_category, store: store,
  option_type: grade_opt,
  variants: [
    { sku: "MNT-CART-STD", label: "Standard", price: 299.99, stock: 20 },
    { sku: "MNT-CART-LRG", label: "Large",    price: 399.99, stock: 10 },
  ]
)

# ============================================================
# Customer user for storefront / connector testing
# ============================================================
customer_email    = ENV.fetch("CUSTOMER_EMAIL", "buyer@hotel.test")
customer_password = ENV.fetch("CUSTOMER_PASSWORD", "testpass123")

customer = Spree::User.find_or_initialize_by(email: customer_email)
customer.password = customer_password
customer.password_confirmation = customer_password
customer.save!
puts "  Customer:  #{customer_email} / #{customer_password}"

puts "\n\n== Done! =="
puts "  Products:  #{Spree::Product.count}"
puts "  Variants:  #{Spree::Variant.count}"
puts "  Taxons:    #{Spree::Taxon.count}"
puts "  Store:     #{store.name} (#{store.url})"
puts "\nAdmin login: #{ENV.fetch('ADMIN_EMAIL', 'spree@example.com')} / #{ENV.fetch('ADMIN_PASSWORD', 'spree123')}"
puts "Storefront:  /login → #{customer_email} / #{customer_password}"
