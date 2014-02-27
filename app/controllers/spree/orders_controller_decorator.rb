Spree::OrdersController.class_eval do
    helper 'spree/products'
    helper 'spree/taxons'

    alias_method :edit_original, :edit
    alias_method :update_original, :update

    def update
        if params[:product]
            @order = current_order(create_order_if_necessary: true)
            variant_id = params[:product].to_i

            line_item = @order.line_items.detect { |line_item| line_item.variant_id == variant_id }

            if line_item.blank?
                logger.debug "Adding product variant:#{variant_id} to the order"
                quantity = 1
                populate_params = {:variants => {variant_id => quantity}}

                populator = Spree::OrderPopulator.new(@order, current_currency)
                if populator.populate(populate_params)
                    @order.ensure_updated_shipments

                    fire_event('spree.cart.add')
                else
                    logger.debug "Failed to add product variant:#{variant_id} to the order"
                    flash[:error] = populator.errors.full_messages.join(" ")
                    redirect_to cart_path and return
                end
            end

            params[:order] = {:line_items_attributes =>
                @order.line_items.map { |li| {:id => li.id, :quantity => li.variant_id == variant_id ? "1" : "0"} },
                :coupon_code => params[:order][:coupon_code]
            }
        end

        logger.debug "Calling original update method with Parameters: #{params}"
        update_original
    end

    def edit
        edit_original

        searcher_params = {:per_page => 50, :page => 1}
        searcher = build_searcher(searcher_params)
        @products = searcher.retrieve_products
        @selected_variant = @order.line_items.any? ? @order.line_items.take().variant : Spree::Variant.where(sku: Spree::Config[:default_item_sku]).take
    end
end