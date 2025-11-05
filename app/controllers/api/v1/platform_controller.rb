module Api
  module V1
    class PlatformController < BaseController
      skip_before_action :authenticate_user!
      skip_authorization_check
      
      # GET /api/v1/platform/metrics
      def metrics
        period = case params[:period]
                when '7d' then 7.days
                when '30d' then 30.days
                when '90d' then 90.days
                else 30.days
                end
        
        platform_service = PlatformTokenService.new
        metrics_data = platform_service.get_metrics(period)
        
        render json: {
          metrics: metrics_data,
          period: params[:period] || '30d'
        }
      end
      
      # GET /api/v1/platform/token
      def token_info
        platform_service = PlatformTokenService.new
        
        # Get platform token info
        token = PlatformToken.first
        
        unless token
          return render json: { error: 'Platform token not initialized' }, status: :not_found
        end
        
        render json: {
          token: {
            name: token.name,
            symbol: token.symbol,
            mint_address: token.mint_address,
            price_usd: token.price_usd,
            market_cap: token.market_cap,
            circulating_supply: token.circulating_supply,
            total_supply: token.total_supply,
            apy: platform_service.calculate_apy
          },
          economics: {
            fee_allocation: {
              buyback_burn: PlatformTokenService::BUYBACK_PERCENTAGE,
              treasury: PlatformTokenService::TREASURY_PERCENTAGE,
              creator_rewards: PlatformTokenService::CREATOR_REWARDS_PERCENTAGE
            },
            fee_sources: [
              { source: 'Token trades (bonding curve)', rate: '0.5%' },
              { source: 'DEX swaps', rate: '0.2%' },
              { source: 'Event tickets', rate: '5%' },
              { source: 'Merch sales', rate: '2.5%' },
              { source: 'Track/album purchases', rate: '5%' }
            ]
          },
          accrual_mechanism: {
            description: 'Platform value accrues through fee collection across all economic activity',
            buyback: 'Regular buyback of platform tokens from market using collected fees',
            burn: 'Purchased tokens are permanently burned, reducing supply',
            rewards: 'Top creators receive weekly rewards in SOL',
            treasury: 'Development fund for platform improvements and sustainability'
          }
        }
      end
    end
  end
end

