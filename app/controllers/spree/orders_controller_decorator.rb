Spree::OrdersController.class_eval do
    helper 'spree/products'
    helper 'spree/taxons'

    alias_method :edit_original, :edit

    def edit
        edit_original

        searcher_params = {:per_page => 50, :page => 1}
        searcher = build_searcher(searcher_params)
        @products = searcher.retrieve_products
    end
end