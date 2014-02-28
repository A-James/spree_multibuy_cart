Spree::Order.class_eval do
    def find_line_item_by_variant_id(variant_id)
        line_items.detect { |line_item| line_item.variant_id == variant_id }
    end
end