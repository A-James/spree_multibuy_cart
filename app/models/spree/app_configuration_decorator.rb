Spree::AppConfiguration.class_eval do
  # The default selected item in the cart when the order is empty.
  preference :default_item_sku, :string, default: "PROD-MAIN"
end
