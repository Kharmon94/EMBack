class CreateFanPassNftSystem < ActiveRecord::Migration[8.0]
  def change
    # Update fan_passes table with NFT fields
    add_column :fan_passes, :max_supply, :integer
    add_column :fan_passes, :minted_count, :integer, default: 0
    add_column :fan_passes, :collection_mint, :string
    add_column :fan_passes, :dividend_percentage, :decimal, precision: 5, scale: 2, default: 0
    add_column :fan_passes, :distribution_type, :integer, default: 0
    add_column :fan_passes, :metadata_uri, :string
    add_column :fan_passes, :revenue_sources, :jsonb, default: []
    add_column :fan_passes, :image_url, :string
    
    # Track individual NFT ownership
    create_table :fan_pass_nfts do |t|
      t.references :fan_pass, null: false, foreign_key: true
      t.references :user, foreign_key: true  # Current owner
      t.string :nft_mint, null: false
      t.integer :edition_number, null: false
      t.integer :status, default: 1  # active by default
      t.decimal :total_dividends_earned, precision: 20, scale: 8, default: 0
      t.datetime :last_dividend_at
      t.datetime :claimed_at
      t.timestamps
      
      t.index :nft_mint, unique: true
      t.index [:fan_pass_id, :edition_number], unique: true
      t.index :status
    end
    
    # Track dividend payments
    create_table :dividends do |t|
      t.references :fan_pass_nft, null: false, foreign_key: true
      t.decimal :amount, precision: 20, scale: 8, null: false
      t.integer :source, default: 0  # streaming, sales, events, tokens, merch
      t.integer :status, default: 0  # pending, processing, paid, failed
      t.string :transaction_signature
      t.date :period_start
      t.date :period_end
      t.text :calculation_details
      t.timestamps
      
      t.index :status
      t.index [:fan_pass_nft_id, :period_start]
      t.index :source
    end
    
    # Platform fee tracking for fan passes
    add_column :platform_metrics, :fan_pass_fees_collected, :decimal, precision: 20, scale: 8, default: 0
    add_column :platform_metrics, :dividends_distributed, :decimal, precision: 20, scale: 8, default: 0
    
    # Indexes for performance
    add_index :fan_passes, :collection_mint, unique: true
    add_index :fan_passes, :dividend_percentage
    add_index :fan_passes, :distribution_type
  end
end

