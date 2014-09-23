Spree::OrdersController.class_eval do
    helper 'spree/products'
    helper 'spree/taxons'

    alias_method :edit_original, :edit
    alias_method :update_original, :update

    def update
      if process_selected_product(params) == false
        return
      end

      logger.debug "Calling original update method with Parameters: #{params}"

      @order = current_order(lock: true)

      # If this is not called before the original update method, the view's
      # variables won't be set before update_original renders the view.
      load_view_variables

      update_original
    end

    def edit
      @order = current_order || Spree::Order.new
      load_view_variables
      edit_original
    end

    private
      def load_view_variables
        selected_variant = selected_variant_or_default(@order)

        @order_total = calculate_order_total_for_variant(@order, selected_variant, current_currency)

        searcher_params = {:per_page => 50, :page => 1}
        searcher = build_searcher(searcher_params)
        @products_and_totals = searcher.retrieve_products.ascend_by_master_price.map { |p| {product: p, selected: selected_variant == p.master, order_total: calculate_order_total_for_variant(@order, p.master, current_currency), per_item_price: calculate_per_item_price(p, current_currency)} }
      end

      def process_selected_product(params)
        if params[:product] == nil
            return true
        end

        variant_id = params[:product].to_i

        @order = current_order(create_order_if_necessary: true)

        if add_variant_to_order_if_not_in_order(variant_id, @order) == false
            return
        end

        ensure_order_only_contains_variant(params, @order, variant_id)

        return true
      end

      def add_variant_to_order_if_not_in_order(variant_id, order)
        if order.find_line_item_by_variant_id(variant_id).blank?
            return add_variant_to_order(variant_id, order)
        end
      end

      def add_variant_to_order(variant_id, order)
        logger.debug "Adding product variant:#{variant_id} to the order"
        quantity = 1
        populate_params = {:variants => {variant_id => quantity}}

        populator = Spree::OrderPopulator.new(order, current_currency)
        if populator.populate(populate_params)
            order.ensure_updated_shipments

            fire_event('spree.cart.add')
        else
            logger.debug "Failed to add product variant:#{variant_id} to the order"
            flash[:error] = populator.errors.full_messages.join(" ")
            redirect_to cart_path and return false
        end

        return true
      end

      def ensure_order_only_contains_variant(params, order, variant_id)
        # Change the parameters so that all line items have a quantity of 0, except for the variant.
        params[:order] = {:line_items_attributes =>
            order.line_items.map { |li| {:id => li.id, :quantity => li.variant_id == variant_id ? "1" : "0"} },
            :coupon_code => params[:order][:coupon_code]
        }
      end

      def selected_variant_or_default(order)
          order.line_items.any? ? order.line_items.first.variant : Spree::Variant.where(sku: Spree::Config[:default_item_sku]).first
      end

      def calculate_order_total_for_variant(order, variant, currency)
        variant_cost = variant.price_in(currency).amount
        order_total = Spree::Money.new((order.total - order.item_total) + variant_cost, { currency: currency })
        return order_total
      end

      def calculate_per_item_price(product, currency)
        items_per_product = product.property('totalNumber').to_i
        if !items_per_product || items_per_product == 0
            items_per_product = 1
        end
        per_item_cost = product.master.price_in(currency).amount / items_per_product
        return Spree::Money.new(per_item_cost, { currency: currency, no_cents: false })
      end
end
