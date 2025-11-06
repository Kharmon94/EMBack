# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_11_06_000018) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "airdrop_claims", force: :cascade do |t|
    t.bigint "airdrop_id", null: false
    t.bigint "user_id", null: false
    t.decimal "amount"
    t.datetime "claimed_at"
    t.string "transaction_signature"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["airdrop_id"], name: "index_airdrop_claims_on_airdrop_id"
    t.index ["user_id"], name: "index_airdrop_claims_on_user_id"
  end

  create_table "airdrops", force: :cascade do |t|
    t.bigint "artist_id", null: false
    t.bigint "artist_token_id", null: false
    t.string "merkle_root"
    t.string "program_address"
    t.decimal "total_amount"
    t.decimal "claimed_amount"
    t.datetime "start_date"
    t.datetime "end_date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["artist_id"], name: "index_airdrops_on_artist_id"
    t.index ["artist_token_id"], name: "index_airdrops_on_artist_token_id"
  end

  create_table "albums", force: :cascade do |t|
    t.bigint "artist_id", null: false
    t.string "title"
    t.text "description"
    t.string "cover_cid"
    t.string "cover_url"
    t.decimal "price"
    t.string "upc"
    t.date "release_date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "likes_count", default: 0, null: false
    t.index ["artist_id"], name: "index_albums_on_artist_id"
    t.index ["likes_count"], name: "index_albums_on_likes_count"
  end

  create_table "artist_tokens", force: :cascade do |t|
    t.bigint "artist_id", null: false
    t.string "name"
    t.string "symbol"
    t.string "mint_address"
    t.string "bonding_curve_address"
    t.decimal "supply"
    t.decimal "market_cap"
    t.boolean "graduated"
    t.datetime "graduation_date"
    t.text "description"
    t.string "image_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "price_usd", precision: 18, scale: 8, default: "0.0"
    t.index ["artist_id"], name: "index_artist_tokens_on_artist_id"
  end

  create_table "artists", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "name"
    t.text "bio"
    t.string "avatar_url"
    t.boolean "verified"
    t.string "banner_url"
    t.string "twitter_handle"
    t.string "instagram_handle"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_artists_on_user_id"
  end

  create_table "comments", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "commentable_type", null: false
    t.bigint "commentable_id", null: false
    t.text "content", null: false
    t.integer "likes_count", default: 0, null: false
    t.bigint "parent_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["commentable_type", "commentable_id", "created_at"], name: "idx_on_commentable_type_commentable_id_created_at_89c6e27600"
    t.index ["commentable_type", "commentable_id"], name: "index_comments_on_commentable"
    t.index ["commentable_type", "commentable_id"], name: "index_comments_on_commentable_type_and_commentable_id"
    t.index ["parent_id"], name: "index_comments_on_parent_id"
    t.index ["user_id"], name: "index_comments_on_user_id"
  end

  create_table "conversation_participants", force: :cascade do |t|
    t.bigint "conversation_id", null: false
    t.bigint "user_id", null: false
    t.datetime "last_read_at"
    t.boolean "archived", default: false
    t.boolean "muted", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["conversation_id", "user_id"], name: "index_conversation_participants_unique", unique: true
    t.index ["conversation_id"], name: "index_conversation_participants_on_conversation_id"
    t.index ["user_id", "archived"], name: "index_conversation_participants_on_user_id_and_archived"
    t.index ["user_id"], name: "index_conversation_participants_on_user_id"
  end

  create_table "conversations", force: :cascade do |t|
    t.string "subject"
    t.bigint "order_id"
    t.datetime "last_message_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["last_message_at"], name: "index_conversations_on_last_message_at"
    t.index ["order_id"], name: "index_conversations_on_order_id"
  end

  create_table "direct_messages", force: :cascade do |t|
    t.bigint "conversation_id", null: false
    t.bigint "user_id", null: false
    t.text "content", null: false
    t.jsonb "attachments", default: []
    t.datetime "read_at"
    t.boolean "system_message", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["conversation_id", "created_at"], name: "index_direct_messages_on_conversation_id_and_created_at"
    t.index ["conversation_id"], name: "index_direct_messages_on_conversation_id"
    t.index ["user_id"], name: "index_direct_messages_on_user_id"
  end

  create_table "dividends", force: :cascade do |t|
    t.bigint "fan_pass_nft_id", null: false
    t.decimal "amount", precision: 20, scale: 8, null: false
    t.integer "source", default: 0
    t.integer "status", default: 0
    t.string "transaction_signature"
    t.date "period_start"
    t.date "period_end"
    t.text "calculation_details"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["fan_pass_nft_id", "period_start"], name: "index_dividends_on_fan_pass_nft_id_and_period_start"
    t.index ["fan_pass_nft_id"], name: "index_dividends_on_fan_pass_nft_id"
    t.index ["source"], name: "index_dividends_on_source"
    t.index ["status"], name: "index_dividends_on_status"
  end

  create_table "events", force: :cascade do |t|
    t.bigint "artist_id", null: false
    t.string "title"
    t.text "description"
    t.string "venue"
    t.string "location"
    t.datetime "start_time"
    t.datetime "end_time"
    t.integer "capacity"
    t.integer "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["artist_id"], name: "index_events_on_artist_id"
  end

  create_table "fan_pass_nfts", force: :cascade do |t|
    t.bigint "fan_pass_id", null: false
    t.bigint "user_id"
    t.string "nft_mint", null: false
    t.integer "edition_number", null: false
    t.integer "status", default: 1
    t.decimal "total_dividends_earned", precision: 20, scale: 8, default: "0.0"
    t.datetime "last_dividend_at"
    t.datetime "claimed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["fan_pass_id", "edition_number"], name: "index_fan_pass_nfts_on_fan_pass_id_and_edition_number", unique: true
    t.index ["fan_pass_id"], name: "index_fan_pass_nfts_on_fan_pass_id"
    t.index ["nft_mint"], name: "index_fan_pass_nfts_on_nft_mint", unique: true
    t.index ["status"], name: "index_fan_pass_nfts_on_status"
    t.index ["user_id"], name: "index_fan_pass_nfts_on_user_id"
  end

  create_table "fan_passes", force: :cascade do |t|
    t.bigint "artist_id", null: false
    t.string "name"
    t.text "description"
    t.decimal "price"
    t.jsonb "perks"
    t.decimal "token_gate_amount"
    t.boolean "active"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "max_supply"
    t.integer "minted_count", default: 0
    t.string "collection_mint"
    t.decimal "dividend_percentage", precision: 5, scale: 2, default: "0.0"
    t.integer "distribution_type", default: 0
    t.string "metadata_uri"
    t.jsonb "revenue_sources", default: []
    t.string "image_url"
    t.integer "likes_count", default: 0, null: false
    t.index ["artist_id"], name: "index_fan_passes_on_artist_id"
    t.index ["collection_mint"], name: "index_fan_passes_on_collection_mint", unique: true
    t.index ["distribution_type"], name: "index_fan_passes_on_distribution_type"
    t.index ["dividend_percentage"], name: "index_fan_passes_on_dividend_percentage"
  end

  create_table "follows", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "followable_type", null: false
    t.bigint "followable_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["followable_type", "followable_id"], name: "index_follows_on_followable"
    t.index ["user_id", "followable_type", "followable_id"], name: "index_follows_on_user_and_followable", unique: true
    t.index ["user_id"], name: "index_follows_on_user_id"
  end

  create_table "jwt_denylists", force: :cascade do |t|
    t.string "jti", null: false
    t.datetime "exp", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["jti"], name: "index_jwt_denylists_on_jti", unique: true
  end

  create_table "likes", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "likeable_type", null: false
    t.bigint "likeable_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["likeable_type", "likeable_id"], name: "index_likes_on_likeable"
    t.index ["likeable_type", "likeable_id"], name: "index_likes_on_likeable_type_and_likeable_id"
    t.index ["user_id", "likeable_type", "likeable_id"], name: "index_likes_on_user_and_likeable", unique: true
    t.index ["user_id"], name: "index_likes_on_user_id"
  end

  create_table "liquidity_pools", force: :cascade do |t|
    t.bigint "artist_token_id", null: false
    t.integer "platform"
    t.string "pool_address"
    t.decimal "reserve_token"
    t.decimal "reserve_sol"
    t.decimal "tvl"
    t.decimal "volume_24h"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["artist_token_id"], name: "index_liquidity_pools_on_artist_token_id"
  end

  create_table "livestreams", force: :cascade do |t|
    t.bigint "artist_id", null: false
    t.string "title"
    t.text "description"
    t.integer "status"
    t.datetime "start_time"
    t.datetime "end_time"
    t.integer "viewer_count"
    t.decimal "token_gate_amount"
    t.string "stream_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "stream_key"
    t.string "rtmp_url"
    t.string "hls_url"
    t.datetime "started_at"
    t.datetime "ended_at"
    t.integer "likes_count", default: 0, null: false
    t.index ["artist_id"], name: "index_livestreams_on_artist_id"
    t.index ["stream_key"], name: "index_livestreams_on_stream_key", unique: true
  end

  create_table "merch_item_tags", force: :cascade do |t|
    t.bigint "merch_item_id", null: false
    t.bigint "product_tag_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["merch_item_id", "product_tag_id"], name: "index_merch_tags_unique", unique: true
    t.index ["merch_item_id"], name: "index_merch_item_tags_on_merch_item_id"
    t.index ["product_tag_id"], name: "index_merch_item_tags_on_product_tag_id"
  end

  create_table "merch_items", force: :cascade do |t|
    t.bigint "artist_id", null: false
    t.string "title"
    t.text "description"
    t.decimal "price"
    t.jsonb "variants"
    t.jsonb "images"
    t.integer "inventory_count"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "product_category_id"
    t.string "sku"
    t.string "brand"
    t.boolean "featured", default: false
    t.decimal "rating_average", precision: 3, scale: 2, default: "0.0"
    t.integer "rating_count", default: 0
    t.integer "view_count", default: 0
    t.integer "purchase_count", default: 0
    t.integer "low_stock_threshold", default: 5
    t.decimal "weight", precision: 8, scale: 2
    t.jsonb "dimensions", default: {}
    t.boolean "token_gated", default: false
    t.integer "minimum_tokens_required", default: 0
    t.boolean "limited_edition", default: false
    t.integer "edition_size"
    t.integer "edition_number"
    t.index ["artist_id"], name: "index_merch_items_on_artist_id"
    t.index ["featured"], name: "index_merch_items_on_featured"
    t.index ["product_category_id"], name: "index_merch_items_on_product_category_id"
    t.index ["sku"], name: "index_merch_items_on_sku", unique: true
  end

  create_table "mini_views", force: :cascade do |t|
    t.bigint "mini_id", null: false
    t.bigint "user_id"
    t.integer "watched_duration"
    t.boolean "completed", default: false
    t.boolean "nft_holder", default: false
    t.string "access_tier"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["completed"], name: "index_mini_views_on_completed"
    t.index ["created_at"], name: "index_mini_views_on_created_at"
    t.index ["mini_id", "user_id"], name: "index_mini_views_on_mini_id_and_user_id"
    t.index ["mini_id"], name: "index_mini_views_on_mini_id"
    t.index ["nft_holder"], name: "index_mini_views_on_nft_holder"
    t.index ["user_id"], name: "index_mini_views_on_user_id"
  end

  create_table "minis", force: :cascade do |t|
    t.bigint "artist_id", null: false
    t.string "title", null: false
    t.text "description"
    t.integer "duration", null: false
    t.string "video_url"
    t.string "thumbnail_url"
    t.decimal "price", precision: 10, scale: 2, default: "0.0"
    t.integer "access_tier", default: 0, null: false
    t.integer "preview_duration", default: 30
    t.integer "views_count", default: 0, null: false
    t.integer "likes_count", default: 0, null: false
    t.integer "shares_count", default: 0, null: false
    t.string "aspect_ratio", default: "9:16"
    t.boolean "published", default: false, null: false
    t.datetime "published_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["access_tier"], name: "index_minis_on_access_tier"
    t.index ["artist_id", "published"], name: "index_minis_on_artist_id_and_published"
    t.index ["artist_id"], name: "index_minis_on_artist_id"
    t.index ["likes_count"], name: "index_minis_on_likes_count"
    t.index ["published_at"], name: "index_minis_on_published_at"
    t.index ["shares_count"], name: "index_minis_on_shares_count"
    t.index ["views_count"], name: "index_minis_on_views_count"
    t.check_constraint "duration > 0 AND duration <= 120", name: "mini_duration_limit"
  end

  create_table "notifications", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "notification_type", null: false
    t.string "title"
    t.text "message"
    t.jsonb "data", default: {}
    t.boolean "read", default: false, null: false
    t.datetime "read_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["notification_type"], name: "index_notifications_on_notification_type"
    t.index ["user_id", "created_at"], name: "index_notifications_on_user_id_and_created_at"
    t.index ["user_id", "read"], name: "index_notifications_on_user_id_and_read"
    t.index ["user_id"], name: "index_notifications_on_user_id"
  end

  create_table "order_items", force: :cascade do |t|
    t.bigint "order_id", null: false
    t.string "orderable_type", null: false
    t.bigint "orderable_id", null: false
    t.integer "quantity"
    t.decimal "price"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["order_id"], name: "index_order_items_on_order_id"
    t.index ["orderable_type", "orderable_id"], name: "index_order_items_on_orderable"
  end

  create_table "orders", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.integer "status"
    t.decimal "total_amount"
    t.jsonb "shipping_address"
    t.string "tracking_number"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "carrier"
    t.datetime "shipped_at"
    t.datetime "delivered_at"
    t.datetime "estimated_delivery"
    t.string "blockchain_receipt_url"
    t.text "notes"
    t.index ["tracking_number"], name: "index_orders_on_tracking_number"
    t.index ["user_id"], name: "index_orders_on_user_id"
  end

  create_table "platform_metrics", force: :cascade do |t|
    t.date "date"
    t.decimal "daily_volume"
    t.decimal "fees_collected"
    t.decimal "tokens_burned"
    t.integer "active_users"
    t.integer "new_tokens"
    t.integer "total_streams"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "fan_pass_fees_collected", precision: 20, scale: 8, default: "0.0"
    t.decimal "dividends_distributed", precision: 20, scale: 8, default: "0.0"
  end

  create_table "platform_tokens", force: :cascade do |t|
    t.string "name"
    t.string "symbol"
    t.string "mint_address"
    t.decimal "total_supply"
    t.decimal "circulating_supply"
    t.decimal "price_usd"
    t.decimal "market_cap"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "playlist_tracks", force: :cascade do |t|
    t.bigint "playlist_id", null: false
    t.bigint "track_id", null: false
    t.integer "position"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["playlist_id"], name: "index_playlist_tracks_on_playlist_id"
    t.index ["track_id"], name: "index_playlist_tracks_on_track_id"
  end

  create_table "playlists", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "title"
    t.text "description"
    t.boolean "is_public"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_playlists_on_user_id"
  end

  create_table "product_categories", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.text "description"
    t.integer "parent_id"
    t.string "image_url"
    t.integer "position", default: 0
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_product_categories_on_active"
    t.index ["parent_id"], name: "index_product_categories_on_parent_id"
    t.index ["slug"], name: "index_product_categories_on_slug", unique: true
  end

  create_table "product_tags", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_product_tags_on_slug", unique: true
  end

  create_table "product_variants", force: :cascade do |t|
    t.bigint "merch_item_id", null: false
    t.string "sku", null: false
    t.string "size"
    t.string "color"
    t.string "material"
    t.decimal "price_modifier", precision: 10, scale: 2, default: "0.0"
    t.integer "inventory_count", default: 0
    t.integer "low_stock_threshold", default: 5
    t.boolean "available", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["available"], name: "index_product_variants_on_available"
    t.index ["merch_item_id"], name: "index_product_variants_on_merch_item_id"
    t.index ["sku"], name: "index_product_variants_on_sku", unique: true
  end

  create_table "purchases", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "purchasable_type", null: false
    t.bigint "purchasable_id", null: false
    t.decimal "price_paid"
    t.string "transaction_signature"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["purchasable_type", "purchasable_id"], name: "index_purchases_on_purchasable"
    t.index ["user_id"], name: "index_purchases_on_user_id"
  end

  create_table "recently_viewed_items", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "merch_item_id", null: false
    t.datetime "viewed_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["merch_item_id"], name: "index_recently_viewed_items_on_merch_item_id"
    t.index ["user_id", "merch_item_id"], name: "index_recently_viewed_items_on_user_id_and_merch_item_id", unique: true
    t.index ["user_id", "viewed_at"], name: "index_recently_viewed_items_on_user_id_and_viewed_at"
    t.index ["user_id"], name: "index_recently_viewed_items_on_user_id"
  end

  create_table "reports", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "reportable_type", null: false
    t.bigint "reportable_id", null: false
    t.text "reason"
    t.integer "status", default: 0
    t.datetime "reviewed_at"
    t.bigint "reviewer_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["reportable_type", "reportable_id"], name: "index_reports_on_reportable"
    t.index ["reportable_type", "reportable_id"], name: "index_reports_on_reportable_type_and_reportable_id"
    t.index ["reviewer_id"], name: "index_reports_on_reviewer_id"
    t.index ["status"], name: "index_reports_on_status"
    t.index ["user_id"], name: "index_reports_on_user_id"
  end

  create_table "revenue_splits", force: :cascade do |t|
    t.string "splittable_type", null: false
    t.bigint "splittable_id", null: false
    t.jsonb "recipients"
    t.jsonb "percentages"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["splittable_type", "splittable_id"], name: "index_revenue_splits_on_splittable"
  end

  create_table "review_votes", force: :cascade do |t|
    t.bigint "review_id", null: false
    t.bigint "user_id", null: false
    t.boolean "helpful", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["review_id", "user_id"], name: "index_review_votes_on_review_id_and_user_id", unique: true
    t.index ["review_id"], name: "index_review_votes_on_review_id"
    t.index ["user_id"], name: "index_review_votes_on_user_id"
  end

  create_table "reviews", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "merch_item_id", null: false
    t.bigint "order_id"
    t.integer "rating", null: false
    t.string "title"
    t.text "content"
    t.boolean "verified_purchase", default: false
    t.string "blockchain_proof_url"
    t.integer "helpful_count", default: 0
    t.integer "not_helpful_count", default: 0
    t.text "artist_response"
    t.datetime "artist_responded_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["merch_item_id", "user_id"], name: "index_reviews_on_merch_item_id_and_user_id", unique: true
    t.index ["merch_item_id"], name: "index_reviews_on_merch_item_id"
    t.index ["order_id"], name: "index_reviews_on_order_id"
    t.index ["rating"], name: "index_reviews_on_rating"
    t.index ["user_id"], name: "index_reviews_on_user_id"
    t.index ["verified_purchase"], name: "index_reviews_on_verified_purchase"
  end

  create_table "stream_messages", force: :cascade do |t|
    t.bigint "livestream_id", null: false
    t.bigint "user_id", null: false
    t.text "content"
    t.decimal "tip_amount"
    t.string "tip_mint"
    t.datetime "sent_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["livestream_id"], name: "index_stream_messages_on_livestream_id"
    t.index ["user_id"], name: "index_stream_messages_on_user_id"
  end

  create_table "streams", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "track_id", null: false
    t.integer "duration"
    t.datetime "listened_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "nft_holder", default: false
    t.string "access_tier"
    t.string "quality"
    t.index ["access_tier"], name: "index_streams_on_access_tier"
    t.index ["nft_holder"], name: "index_streams_on_nft_holder"
    t.index ["track_id"], name: "index_streams_on_track_id"
    t.index ["user_id"], name: "index_streams_on_user_id"
  end

  create_table "ticket_tiers", force: :cascade do |t|
    t.bigint "event_id", null: false
    t.string "name"
    t.text "description"
    t.decimal "price"
    t.integer "quantity"
    t.integer "sold"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_ticket_tiers_on_event_id"
  end

  create_table "tickets", force: :cascade do |t|
    t.bigint "ticket_tier_id", null: false
    t.bigint "user_id", null: false
    t.string "nft_mint"
    t.integer "status"
    t.string "qr_code"
    t.datetime "purchased_at"
    t.datetime "used_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ticket_tier_id"], name: "index_tickets_on_ticket_tier_id"
    t.index ["user_id"], name: "index_tickets_on_user_id"
  end

  create_table "tracks", force: :cascade do |t|
    t.bigint "album_id", null: false
    t.string "title"
    t.integer "duration"
    t.string "audio_cid"
    t.string "audio_url"
    t.string "isrc"
    t.integer "track_number"
    t.decimal "price"
    t.boolean "explicit"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "access_tier", default: 0, null: false
    t.integer "free_quality", default: 0, null: false
    t.integer "likes_count", default: 0, null: false
    t.index ["access_tier"], name: "index_tracks_on_access_tier"
    t.index ["album_id", "access_tier"], name: "index_tracks_on_album_id_and_access_tier"
    t.index ["album_id"], name: "index_tracks_on_album_id"
    t.index ["likes_count"], name: "index_tracks_on_likes_count"
  end

  create_table "trades", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "artist_token_id", null: false
    t.decimal "amount"
    t.decimal "price"
    t.integer "trade_type"
    t.string "transaction_signature"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["artist_token_id"], name: "index_trades_on_artist_token_id"
    t.index ["user_id"], name: "index_trades_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: ""
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.string "wallet_address", null: false
    t.integer "role", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "display_name"
    t.text "bio"
    t.string "avatar_url"
    t.jsonb "social_links", default: {}
    t.integer "followers_count", default: 0, null: false
    t.integer "following_count", default: 0, null: false
    t.jsonb "notification_preferences", default: {"likes"=>true, "comments"=>true, "followers"=>true, "purchases"=>true, "livestreams"=>true, "email_enabled"=>true}
    t.datetime "deleted_at"
    t.boolean "suspended", default: false
    t.datetime "suspended_at"
    t.text "suspension_reason"
    t.boolean "banned", default: false
    t.datetime "banned_at"
    t.text "ban_reason"
    t.integer "accept_messages", default: 0
    t.integer "blocked_user_ids", default: [], array: true
    t.index ["banned"], name: "index_users_on_banned"
    t.index ["blocked_user_ids"], name: "index_users_on_blocked_user_ids", using: :gin
    t.index ["deleted_at"], name: "index_users_on_deleted_at"
    t.index ["display_name"], name: "index_users_on_display_name"
    t.index ["email"], name: "index_users_on_email"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["role"], name: "index_users_on_role"
    t.index ["suspended"], name: "index_users_on_suspended"
    t.index ["wallet_address"], name: "index_users_on_wallet_address", unique: true
  end

  create_table "video_views", force: :cascade do |t|
    t.bigint "video_id", null: false
    t.bigint "user_id"
    t.integer "watched_duration"
    t.boolean "completed", default: false
    t.boolean "nft_holder", default: false
    t.string "access_tier"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["completed"], name: "index_video_views_on_completed"
    t.index ["created_at"], name: "index_video_views_on_created_at"
    t.index ["nft_holder"], name: "index_video_views_on_nft_holder"
    t.index ["user_id"], name: "index_video_views_on_user_id"
    t.index ["video_id", "user_id"], name: "index_video_views_on_video_id_and_user_id"
    t.index ["video_id"], name: "index_video_views_on_video_id"
  end

  create_table "videos", force: :cascade do |t|
    t.bigint "artist_id", null: false
    t.string "title", null: false
    t.text "description"
    t.integer "duration"
    t.string "video_url"
    t.string "thumbnail_url"
    t.decimal "price", precision: 10, scale: 2, default: "0.0"
    t.integer "access_tier", default: 0, null: false
    t.integer "preview_duration", default: 60
    t.integer "views_count", default: 0, null: false
    t.integer "likes_count", default: 0, null: false
    t.boolean "published", default: false, null: false
    t.datetime "published_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["access_tier"], name: "index_videos_on_access_tier"
    t.index ["artist_id", "published"], name: "index_videos_on_artist_id_and_published"
    t.index ["artist_id"], name: "index_videos_on_artist_id"
    t.index ["likes_count"], name: "index_videos_on_likes_count"
    t.index ["published_at"], name: "index_videos_on_published_at"
    t.index ["views_count"], name: "index_videos_on_views_count"
  end

  create_table "wishlist_items", force: :cascade do |t|
    t.bigint "wishlist_id", null: false
    t.bigint "merch_item_id", null: false
    t.bigint "product_variant_id"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["merch_item_id"], name: "index_wishlist_items_on_merch_item_id"
    t.index ["product_variant_id"], name: "index_wishlist_items_on_product_variant_id"
    t.index ["wishlist_id", "merch_item_id"], name: "index_wishlist_items_on_wishlist_id_and_merch_item_id", unique: true
    t.index ["wishlist_id"], name: "index_wishlist_items_on_wishlist_id"
  end

  create_table "wishlists", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "name", default: "My Wishlist", null: false
    t.text "description"
    t.boolean "public", default: false
    t.string "share_token"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["share_token"], name: "index_wishlists_on_share_token", unique: true
    t.index ["user_id", "public"], name: "index_wishlists_on_user_id_and_public"
    t.index ["user_id"], name: "index_wishlists_on_user_id"
  end

  add_foreign_key "airdrop_claims", "airdrops"
  add_foreign_key "airdrop_claims", "users"
  add_foreign_key "airdrops", "artist_tokens"
  add_foreign_key "airdrops", "artists"
  add_foreign_key "albums", "artists"
  add_foreign_key "artist_tokens", "artists"
  add_foreign_key "artists", "users"
  add_foreign_key "comments", "comments", column: "parent_id"
  add_foreign_key "comments", "users"
  add_foreign_key "conversation_participants", "conversations"
  add_foreign_key "conversation_participants", "users"
  add_foreign_key "conversations", "orders"
  add_foreign_key "direct_messages", "conversations"
  add_foreign_key "direct_messages", "users"
  add_foreign_key "dividends", "fan_pass_nfts"
  add_foreign_key "events", "artists"
  add_foreign_key "fan_pass_nfts", "fan_passes"
  add_foreign_key "fan_pass_nfts", "users"
  add_foreign_key "fan_passes", "artists"
  add_foreign_key "follows", "users"
  add_foreign_key "likes", "users"
  add_foreign_key "liquidity_pools", "artist_tokens"
  add_foreign_key "livestreams", "artists"
  add_foreign_key "merch_item_tags", "merch_items"
  add_foreign_key "merch_item_tags", "product_tags"
  add_foreign_key "merch_items", "artists"
  add_foreign_key "merch_items", "product_categories"
  add_foreign_key "mini_views", "minis"
  add_foreign_key "mini_views", "users"
  add_foreign_key "minis", "artists"
  add_foreign_key "notifications", "users"
  add_foreign_key "order_items", "orders"
  add_foreign_key "orders", "users"
  add_foreign_key "playlist_tracks", "playlists"
  add_foreign_key "playlist_tracks", "tracks"
  add_foreign_key "playlists", "users"
  add_foreign_key "product_variants", "merch_items"
  add_foreign_key "purchases", "users"
  add_foreign_key "recently_viewed_items", "merch_items"
  add_foreign_key "recently_viewed_items", "users"
  add_foreign_key "reports", "users"
  add_foreign_key "reports", "users", column: "reviewer_id"
  add_foreign_key "review_votes", "reviews"
  add_foreign_key "review_votes", "users"
  add_foreign_key "reviews", "merch_items"
  add_foreign_key "reviews", "orders"
  add_foreign_key "reviews", "users"
  add_foreign_key "stream_messages", "livestreams"
  add_foreign_key "stream_messages", "users"
  add_foreign_key "streams", "tracks"
  add_foreign_key "streams", "users"
  add_foreign_key "ticket_tiers", "events"
  add_foreign_key "tickets", "ticket_tiers"
  add_foreign_key "tickets", "users"
  add_foreign_key "tracks", "albums"
  add_foreign_key "trades", "artist_tokens"
  add_foreign_key "trades", "users"
  add_foreign_key "video_views", "users"
  add_foreign_key "video_views", "videos"
  add_foreign_key "videos", "artists"
  add_foreign_key "wishlist_items", "merch_items"
  add_foreign_key "wishlist_items", "product_variants"
  add_foreign_key "wishlist_items", "wishlists"
  add_foreign_key "wishlists", "users"
end
