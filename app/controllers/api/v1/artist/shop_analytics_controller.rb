module Api
  module V1
    module Artist
      class ShopAnalyticsController < BaseController
        before_action :require_artist_role
        
        # GET /api/v1/artist/shop_analytics
        def index
          render json: {
            revenue: revenue_analytics,
            products: product_analytics,
            customers: customer_analytics,
            conversion: conversion_analytics
          }
        end
        
        # GET /api/v1/artist/shop_analytics/export
        def export
          csv_data = generate_analytics_csv
          send_data csv_data, filename: "shop_analytics_#{Date.today}.csv", type: 'text/csv'
        end
        
        private
        
        def require_artist_role
          unless current_user&.artist?
            render json: { error: 'Artist access required' }, status: :forbidden
          end
        end
        
        def revenue_analytics
          orders = ::Order.for_artist(current_artist.id).where(status: [:paid, :processing, :shipped, :delivered])
          
          {
            total_revenue: orders.sum(:total_amount),
            revenue_this_month: orders.where('created_at >= ?', 1.month.ago).sum(:total_amount),
            revenue_this_week: orders.where('created_at >= ?', 1.week.ago).sum(:total_amount),
            avg_order_value: orders.average(:total_amount)&.to_f || 0,
            daily_revenue: orders.where('created_at >= ?', 30.days.ago)
                                .group("DATE(created_at)")
                                .sum(:total_amount)
          }
        end
        
        def product_analytics
          merch_items = current_artist.merch_items
          
          {
            total_products: merch_items.count,
            in_stock_products: merch_items.in_stock.count,
            out_of_stock_products: merch_items.where('inventory_count = 0').count,
            low_stock_products: merch_items.select { |item| item.low_stock? }.count,
            avg_rating: merch_items.average(:rating_average)&.to_f || 0,
            total_reviews: merch_items.sum(:rating_count),
            best_sellers: merch_items.popular.limit(10).map { |item|
              {
                id: item.id,
                title: item.title,
                purchase_count: item.purchase_count,
                revenue: item.purchase_count * item.price
              }
            }
          }
        end
        
        def customer_analytics
          orders = ::Order.for_artist(current_artist.id).where(status: [:paid, :processing, :shipped, :delivered])
          
          {
            total_customers: orders.select(:user_id).distinct.count,
            repeat_customers: orders.group(:user_id).having('COUNT(*) > 1').count.length,
            new_customers_this_month: orders.where('created_at >= ?', 1.month.ago).select(:user_id).distinct.count,
            top_customers: orders.group(:user_id)
                                .select('user_id, SUM(total_amount) as total_spent, COUNT(*) as order_count')
                                .order('total_spent DESC')
                                .limit(10)
                                .map { |o|
              user = ::User.find(o.user_id)
              {
                id: user.id,
                email: user.email,
                total_spent: o.total_spent,
                order_count: o.order_count
              }
            }
          }
        end
        
        def conversion_analytics
          merch_items = current_artist.merch_items
          total_views = merch_items.sum(:view_count)
          total_purchases = merch_items.sum(:purchase_count)
          
          {
            total_views: total_views,
            total_purchases: total_purchases,
            conversion_rate: total_views > 0 ? ((total_purchases.to_f / total_views) * 100).round(2) : 0,
            views_this_week: merch_items.where('updated_at >= ?', 1.week.ago).sum(:view_count)
          }
        end
        
        def generate_analytics_csv
          require 'csv'
          
          CSV.generate(headers: true) do |csv|
            csv << ['Metric', 'Value']
            
            revenue = revenue_analytics
            csv << ['Total Revenue', revenue[:total_revenue]]
            csv << ['Revenue This Month', revenue[:revenue_this_month]]
            csv << ['Avg Order Value', revenue[:avg_order_value]]
            
            products = product_analytics
            csv << ['Total Products', products[:total_products]]
            csv << ['In Stock', products[:in_stock_products]]
            csv << ['Low Stock', products[:low_stock_products]]
            
            customers = customer_analytics
            csv << ['Total Customers', customers[:total_customers]]
            csv << ['Repeat Customers', customers[:repeat_customers]]
          end
        end
      end
    end
  end
end

