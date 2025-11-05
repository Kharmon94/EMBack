module Api
  module V1
    class ArtistTokensController < BaseController
      skip_before_action :authenticate_user!, only: [:index, :show, :trades, :chart], raise: false
      load_and_authorize_resource except: [:create, :index, :show, :trades, :chart]
      skip_authorization_check only: [:index, :show, :trades, :chart]
      
      # GET /api/v1/tokens
      def index
        @tokens = ArtistToken.includes(:artist)
        
        # Filter by graduated status
        @tokens = @tokens.graduated if params[:graduated] == 'true'
        @tokens = @tokens.active if params[:active] == 'true'
        
        # Filter by artist
        @tokens = @tokens.where(artist_id: params[:artist_id]) if params[:artist_id]
        
        # Search
        @tokens = @tokens.where('name ILIKE ? OR symbol ILIKE ?', "%#{params[:q]}%", "%#{params[:q]}%") if params[:q].present?
        
        # Sort
        @tokens = case params[:sort]
                  when 'market_cap' then @tokens.order(market_cap: :desc)
                  when 'volume' then @tokens.left_joins(:trades).group(:id).order('COUNT(trades.id) DESC')
                  when 'recent' then @tokens.order(created_at: :desc)
                  else @tokens.order(name: :asc)
                  end
        
        @paginated = paginate(@tokens)
        
        render json: {
          tokens: @paginated.map { |token| token_json(token) },
          meta: pagination_meta(@tokens, @paginated)
        }
      end
      
      # GET /api/v1/tokens/:id
      def show
        @artist_token = ArtistToken.includes(:artist).find(params[:id])
        render json: {
          token: detailed_token_json(@artist_token),
          stats: token_stats(@artist_token)
        }
      end
      
      # POST /api/v1/tokens
      def create
        authorize! :create, ArtistToken
        
        unless current_artist
          return render json: { error: 'Artist profile required to launch token' }, status: :forbidden
        end
        
        # Check if current artist already has a token
        if current_artist.artist_token.present?
          return render json: { error: 'Artist already has a token' }, status: :unprocessable_entity
        end
        
        # DEFENSE-IN-DEPTH: Explicit wallet-level check
        # Ensures one token per wallet even if user somehow has multiple artist profiles
        if ArtistToken.joins(artist: :user).exists?(users: { wallet_address: current_user.wallet_address })
          return render json: { 
            error: 'This wallet has already created a token',
            message: 'Each wallet can only create one artist token. This ensures authenticity and prevents spam.'
          }, status: :unprocessable_entity
        end
        
        # TODO: Create token on Solana using bonding curve program
        # For now, create database record
        
        @artist_token = current_artist.build_artist_token(token_params)
        @artist_token.graduated = false
        @artist_token.supply = params[:initial_supply] || 1_000_000_000
        
        if @artist_token.save
          # TODO: Call Solana program to create token
          # TODO: Automatically revoke mint/freeze authorities
          # TODO: Lock metadata
          
          render json: {
            token: detailed_token_json(@artist_token),
            message: 'Token launched successfully',
            warning: 'Solana program integration pending'
          }, status: :created
        else
          render json: { errors: @artist_token.errors }, status: :unprocessable_entity
        end
      end
      
      # POST /api/v1/tokens/:id/buy
      def buy
        authorize! :create, Trade
        
        amount = params[:amount].to_f
        max_price = params[:max_price].to_f
        signature = params[:transaction_signature]
        
        unless amount > 0 && max_price > 0 && signature.present?
          return render json: { error: 'Invalid parameters' }, status: :bad_request
        end
        
        # TODO: Verify Solana transaction
        # TODO: Calculate price from bonding curve
        # TODO: Check slippage
        
        current_price = calculate_bonding_curve_price(@artist_token, :buy, amount)
        
        if current_price > max_price
          return render json: { 
            error: 'Price exceeds max price (slippage)',
            current_price: current_price,
            max_price: max_price
          }, status: :unprocessable_entity
        end
        
        trade = Trade.create!(
          user: current_user,
          artist_token: @artist_token,
          amount: amount,
          price: current_price,
          trade_type: :buy,
          transaction_signature: signature
        )
        
        # Update token stats
        update_token_stats(@artist_token)
        
        # Broadcast trade to WebSocket
        broadcast_trade(trade)
        
        # Check if token should graduate
        check_graduation(@artist_token)
        
        render json: {
          trade: trade_json(trade),
          token: token_json(@artist_token),
          message: 'Purchase successful'
        }
      end
      
      # POST /api/v1/tokens/:id/sell
      def sell
        authorize! :create, Trade
        
        amount = params[:amount].to_f
        min_price = params[:min_price].to_f
        signature = params[:transaction_signature]
        
        unless amount > 0 && min_price > 0 && signature.present?
          return render json: { error: 'Invalid parameters' }, status: :bad_request
        end
        
        # TODO: Verify Solana transaction
        # TODO: Calculate price from bonding curve
        # TODO: Check slippage
        
        current_price = calculate_bonding_curve_price(@artist_token, :sell, amount)
        
        if current_price < min_price
          return render json: { 
            error: 'Price below min price (slippage)',
            current_price: current_price,
            min_price: min_price
          }, status: :unprocessable_entity
        end
        
        trade = Trade.create!(
          user: current_user,
          artist_token: @artist_token,
          amount: amount,
          price: current_price,
          trade_type: :sell,
          transaction_signature: signature
        )
        
        # Update token stats
        update_token_stats(@artist_token)
        
        # Broadcast trade to WebSocket
        broadcast_trade(trade)
        
        render json: {
          trade: trade_json(trade),
          token: token_json(@artist_token),
          message: 'Sale successful'
        }
      end
      
      # GET /api/v1/tokens/:id/trades
      def trades
        @artist_token = ArtistToken.find(params[:id])
        @trades = @artist_token.trades.includes(:user).recent
        @paginated = paginate(@trades)
        
        render json: {
          trades: @paginated.map { |trade| trade_json(trade) },
          meta: pagination_meta(@trades, @paginated)
        }
      end
      
      # GET /api/v1/tokens/:id/chart
      def chart
        @artist_token = ArtistToken.find(params[:id])
        # Get price history for charting
        timeframe = params[:timeframe] || '24h'
        
        trades = case timeframe
                 when '1h' then @artist_token.trades.where('created_at >= ?', 1.hour.ago)
                 when '24h' then @artist_token.trades.where('created_at >= ?', 24.hours.ago)
                 when '7d' then @artist_token.trades.where('created_at >= ?', 7.days.ago)
                 when '30d' then @artist_token.trades.where('created_at >= ?', 30.days.ago)
                 else @artist_token.trades.where('created_at >= ?', 24.hours.ago)
                 end
        
        chart_data = trades.order(created_at: :asc).map do |trade|
          {
            timestamp: trade.created_at.to_i,
            price: trade.price,
            amount: trade.amount,
            type: trade.trade_type
          }
        end
        
        render json: {
          chart_data: chart_data,
          current_price: @artist_token.market_cap.to_f / @artist_token.supply.to_f,
          timeframe: timeframe
        }
      end
      
      private
      
      def token_params
        params.require(:artist_token).permit(
          :name, :symbol, :description, :image_url
        )
      end
      
      def token_json(token)
        {
          id: token.id,
          name: token.name,
          symbol: token.symbol,
          mint_address: token.mint_address,
          description: token.description,
          image_url: token.image_url,
          supply: token.supply,
          market_cap: token.market_cap,
          graduated: token.graduated,
          graduation_date: token.graduation_date,
          bonding_curve_address: token.bonding_curve_address,
          artist: {
            id: token.artist.id,
            name: token.artist.name,
            avatar_url: token.artist.avatar_url,
            verified: token.artist.verified
          }
        }
      end
      
      def detailed_token_json(token)
        token_json(token).merge(
          holders_count: token.trades.select(:user_id).distinct.count,
          trades_count: token.trades.count,
          volume_24h: token.trades.where('created_at >= ?', 24.hours.ago).sum(:amount),
          ready_to_graduate: token.ready_to_graduate?,
          created_at: token.created_at
        )
      end
      
      def token_stats(token)
        {
          total_trades: token.trades.count,
          total_volume: token.trades.sum('amount * price'),
          unique_traders: token.trades.select(:user_id).distinct.count,
          buys_24h: token.trades.buy.where('created_at >= ?', 24.hours.ago).count,
          sells_24h: token.trades.sell.where('created_at >= ?', 24.hours.ago).count,
          price_change_24h: calculate_price_change(token, 24.hours)
        }
      end
      
      def trade_json(trade)
        {
          id: trade.id,
          type: trade.trade_type,
          amount: trade.amount,
          price: trade.price,
          total: trade.amount * trade.price,
          timestamp: trade.created_at.to_i,
          user: {
            wallet_address: trade.user.wallet_address
          },
          transaction_signature: trade.transaction_signature
        }
      end
      
      # Calculate bonding curve price (simplified - replace with actual program logic)
      def calculate_bonding_curve_price(token, trade_type, amount)
        # Placeholder bonding curve formula
        # TODO: Replace with actual Solana program price calculation
        
        base_price = 0.0001 # Starting price
        supply = token.supply.to_f
        
        # Simple exponential curve: price = base_price * (1 + supply/1000000000)^2
        if trade_type == :buy
          (base_price * (1 + supply / 1_000_000_000) ** 2).round(8)
        else
          (base_price * (1 + (supply - amount) / 1_000_000_000) ** 2).round(8)
        end
      end
      
      def update_token_stats(token)
        # Recalculate market cap based on last trade price
        last_trade = token.trades.order(created_at: :desc).first
        if last_trade
          token.update(
            market_cap: token.supply * last_trade.price
          )
        end
      end
      
      def broadcast_trade(trade)
        ActionCable.server.broadcast(
          "trades:#{trade.artist_token_id}",
          {
            type: 'new_trade',
            trade: trade_json(trade)
          }
        )
      end
      
      def check_graduation(token)
        if token.ready_to_graduate? && !token.graduated
          # TODO: Trigger graduation job to migrate liquidity to Raydium
          GraduationJob.perform_later(token.id)
        end
      end
      
      def calculate_price_change(token, period)
        recent_trade = token.trades.where('created_at >= ?', period.ago).order(created_at: :asc).first
        latest_trade = token.trades.order(created_at: :desc).first
        
        return 0 unless recent_trade && latest_trade
        
        ((latest_trade.price - recent_trade.price) / recent_trade.price * 100).round(2)
      end
    end
  end
end

