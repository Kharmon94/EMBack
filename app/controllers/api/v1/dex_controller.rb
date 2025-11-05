module Api
  module V1
    class DexController < BaseController
      skip_before_action :authenticate_user!, only: [:pools, :show], raise: false
      skip_authorization_check only: [:pools, :show, :swap, :add_liquidity, :remove_liquidity]
      
      # POST /api/v1/dex/swap
      def swap
        authorize! :create, Trade
        
        from_mint = params[:from_mint]
        to_mint = params[:to_mint]
        amount = params[:amount].to_f
        min_amount_out = params[:min_amount_out].to_f
        slippage = params[:slippage]&.to_f || 0.01
        
        unless from_mint && to_mint && amount > 0 && min_amount_out > 0
          return render json: { error: 'Invalid swap parameters' }, status: :bad_request
        end
        
        # Execute swap through DEX service
        dex_service = DexService.new
        result = dex_service.swap(from_mint, to_mint, amount, min_amount_out, current_user.wallet_address, slippage)
        
        if result[:success]
          render json: result
        else
          render json: result, status: :unprocessable_entity
        end
      end
      
      # GET /api/v1/dex/pools
      def pools
        @pools = LiquidityPool.includes(:artist_token)
        
        # Filter by platform
        @pools = @pools.where(platform: params[:platform]) if params[:platform]
        
        # Sort by TVL
        @pools = @pools.order(tvl: :desc)
        
        @paginated = paginate(@pools)
        
        render json: {
          pools: @paginated.map { |pool| pool_json(pool) },
          meta: pagination_meta(@pools, @paginated)
        }
      end
      
      # GET /api/v1/dex/pools/:id
      def show
        @pool = LiquidityPool.find(params[:id])
        
        dex_service = DexService.new
        pool_info = dex_service.get_pool_info(@pool.id)
        
        render json: pool_info
      end
      
      # POST /api/v1/dex/pools/:id/add_liquidity
      def add_liquidity
        authorize! :create, LiquidityPool
        
        pool_id = params[:id]
        token_amount = params[:token_amount].to_f
        sol_amount = params[:sol_amount].to_f
        signature = params[:transaction_signature]
        
        unless token_amount > 0 && sol_amount > 0 && signature.present?
          return render json: { error: 'Invalid liquidity parameters' }, status: :bad_request
        end
        
        # TODO: Verify Solana transaction
        
        dex_service = DexService.new
        result = dex_service.add_liquidity(pool_id, token_amount, sol_amount, current_user.wallet_address)
        
        if result[:success]
          render json: result
        else
          render json: result, status: :unprocessable_entity
        end
      end
      
      # POST /api/v1/dex/pools/:id/remove_liquidity
      def remove_liquidity
        authorize! :create, LiquidityPool
        
        pool_id = params[:id]
        lp_tokens = params[:lp_tokens].to_f
        signature = params[:transaction_signature]
        
        unless lp_tokens > 0 && signature.present?
          return render json: { error: 'Invalid liquidity removal parameters' }, status: :bad_request
        end
        
        # TODO: Verify Solana transaction
        
        dex_service = DexService.new
        result = dex_service.remove_liquidity(pool_id, lp_tokens, current_user.wallet_address)
        
        if result[:success]
          render json: result
        else
          render json: result, status: :unprocessable_entity
        end
      end
      
      private
      
      def pool_json(pool)
        {
          id: pool.id,
          platform: pool.platform,
          pool_address: pool.pool_address,
          reserve_token: pool.reserve_token,
          reserve_sol: pool.reserve_sol,
          tvl: pool.tvl,
          price: pool.price,
          volume_24h: pool.volume_24h,
          token: {
            id: pool.artist_token.id,
            name: pool.artist_token.name,
            symbol: pool.artist_token.symbol,
            mint_address: pool.artist_token.mint_address
          },
          artist: {
            id: pool.artist_token.artist.id,
            name: pool.artist_token.artist.name
          }
        }
      end
    end
  end
end

