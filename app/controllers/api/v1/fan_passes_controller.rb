module Api
  module V1
    class FanPassesController < BaseController
      skip_before_action :authenticate_user!, only: [:index, :show], raise: false
      load_and_authorize_resource except: [:index, :show]
      skip_authorization_check only: [:index, :show]
      
      # GET /api/v1/fan_passes
      def index
        @fan_passes = FanPass.includes(:artist)
        
        # Filter by artist
        @fan_passes = @fan_passes.where(artist_id: params[:artist_id]) if params[:artist_id]
        
        # Filter by active
        @fan_passes = @fan_passes.where(active: true) if params[:active] == 'true'
        
        @fan_passes = @fan_passes.order(created_at: :desc)
        @paginated = paginate(@fan_passes)
        
        render json: {
          fan_passes: @paginated.map { |pass| fan_pass_json(pass) },
          meta: pagination_meta(@fan_passes, @paginated)
        }
      end
      
      # GET /api/v1/fan_passes/:id
      def show
        # Check if user owns this pass
        ownership_status = if current_user
                            check_ownership(current_user, @fan_pass)
                          else
                            { owned: false }
                          end
        
        render json: {
          fan_pass: detailed_fan_pass_json(@fan_pass),
          ownership: ownership_status
        }
      end
      
      # POST /api/v1/fan_passes
      def create
        @fan_pass = current_artist.fan_passes.build(fan_pass_params)
        
        if @fan_pass.save
          render json: {
            fan_pass: detailed_fan_pass_json(@fan_pass),
            message: 'Fan pass created successfully'
          }, status: :created
        else
          render json: { errors: @fan_pass.errors }, status: :unprocessable_entity
        end
      end
      
      # PATCH /api/v1/fan_passes/:id
      def update
        if @fan_pass.update(fan_pass_params)
          render json: { fan_pass: detailed_fan_pass_json(@fan_pass) }
        else
          render json: { errors: @fan_pass.errors }, status: :unprocessable_entity
        end
      end
      
      # DELETE /api/v1/fan_passes/:id
      def destroy
        @fan_pass.update!(active: false)
        render json: { message: 'Fan pass deactivated successfully' }
      end
      
      # POST /api/v1/fan_passes/:id/purchase
      def purchase
        authorize! :create, FanPassNft
        
        # Check availability
        if @fan_pass.sold_out?
          return render json: { error: 'Fan pass sold out' }, status: :unprocessable_entity
        end
        
        # Verify payment if required
        if @fan_pass.paid? && @fan_pass.price > 0
          signature = params[:transaction_signature]
          unless signature
            return render json: { error: 'Payment signature required' }, status: :bad_request
          end
          
          # TODO: Verify Solana transaction
        end
        
        begin
          service = FanPassService.new(@fan_pass)
          result = service.mint_nft(current_user, params[:transaction_signature])
          
          render json: {
            nft: fan_pass_nft_json(result[:nft]),
            edition_number: result[:edition_number],
            platform_fee: result[:platform_fee],
            message: "Fan pass NFT ##{result[:edition_number]} minted successfully!",
            perks: @fan_pass.perks,
            dividend_info: @fan_pass.has_dividends? ? {
              dividend_rate: @fan_pass.dividend_percentage,
              revenue_sources: @fan_pass.revenue_sources,
              estimated_monthly: "Varies based on artist revenue"
            } : nil
          }, status: :created
        rescue => e
          render json: { error: e.message }, status: :unprocessable_entity
        end
      end
      
      # GET /api/v1/fan_passes/:id/holders
      def holders
        nfts = @fan_pass.fan_pass_nfts.active.includes(:user).order(edition_number: :asc)
        
        render json: {
          holders: nfts.map { |nft| holder_json(nft) },
          total_count: nfts.count,
          active_count: @fan_pass.active_count
        }
      end
      
      # GET /api/v1/fan_passes/:id/dividends
      def dividends_history
        dividends = @fan_pass.dividends.includes(:fan_pass_nft).recent.limit(100)
        
        render json: {
          dividends: dividends.map { |div| dividend_json(div) },
          summary: {
            total_distributed: @fan_pass.dividends.paid.sum(:amount),
            last_distribution: @fan_pass.dividends.paid.maximum(:created_at),
            pending_amount: @fan_pass.dividends.pending.sum(:amount)
          }
        }
      end
      
      # POST /api/v1/fan_passes/:id/distribute_dividends (Artist only)
      def distribute_dividends
        authorize! :update, @fan_pass
        
        unless current_user.artist && @fan_pass.artist_id == current_user.artist.id
          return render json: { error: 'Only the artist can distribute dividends' }, status: :forbidden
        end
        
        period_start = params[:period_start]&.to_date || 1.month.ago.to_date
        period_end = params[:period_end]&.to_date || Date.today
        revenue_by_source = params[:revenue_by_source] || {}
        
        service = FanPassService.new(@fan_pass)
        result = service.distribute_dividends(period_start, period_end, revenue_by_source)
        
        if result[:success]
          render json: {
            message: "Dividends calculated for #{result[:active_holders]} holders",
            total_pool: result[:total_pool],
            per_holder: result[:per_holder],
            dividends_created: result[:dividends_created]
          }
        else
          render json: { error: result[:error] }, status: :unprocessable_entity
        end
      end
      
      private
      
      def fan_pass_params
        params.require(:fan_pass).permit(
          :name, :description, :price, :max_supply, :dividend_percentage, 
          :distribution_type, :image_url, :active,
          perks: {},
          revenue_sources: []
        )
      end
      
      def fan_pass_json(pass)
        {
          id: pass.id,
          name: pass.name,
          description: pass.description,
          price: pass.price,
          max_supply: pass.max_supply,
          minted_count: pass.minted_count,
          available_supply: pass.available_supply,
          sold_out: pass.sold_out?,
          dividend_percentage: pass.dividend_percentage,
          revenue_sources: pass.revenue_sources,
          perks: pass.perks,
          total_perks: pass.total_perks_count,
          image_url: pass.image_url,
          active: pass.active,
          artist: {
            id: pass.artist.id,
            name: pass.artist.name,
            avatar_url: pass.artist.avatar_url,
            verified: pass.artist.verified
          }
        }
      end
      
      def detailed_fan_pass_json(pass)
        fan_pass_json(pass).merge(
          holders_count: pass.active_count,
          collection_mint: pass.collection_mint,
          total_dividends_distributed: pass.dividends.paid.sum(:amount),
          last_dividend_date: pass.dividends.paid.maximum(:created_at),
          created_at: pass.created_at,
          updated_at: pass.updated_at
        )
      end
      
      def fan_pass_nft_json(nft)
        {
          id: nft.id,
          nft_mint: nft.nft_mint,
          edition_number: nft.edition_number,
          status: nft.status,
          total_dividends_earned: nft.total_dividends_earned,
          last_dividend_at: nft.last_dividend_at,
          claimed_at: nft.claimed_at,
          owner: nft.user ? { wallet_address: nft.user.wallet_address } : nil
        }
      end
      
      def holder_json(nft)
        {
          edition_number: nft.edition_number,
          nft_mint: nft.nft_mint,
          owner: nft.user.wallet_address,
          total_earned: nft.total_dividends_earned,
          last_payment: nft.last_dividend_at,
          status: nft.status
        }
      end
      
      def dividend_json(dividend)
        {
          id: dividend.id,
          amount: dividend.amount,
          source: dividend.source,
          status: dividend.status,
          period_start: dividend.period_start,
          period_end: dividend.period_end,
          transaction_signature: dividend.transaction_signature,
          created_at: dividend.created_at
        }
      end
      
      def check_ownership(user, fan_pass)
        nft = fan_pass.fan_pass_nfts.active.find_by(user: user)
        
        if nft
          {
            owned: true,
            nft: fan_pass_nft_json(nft),
            perks_unlocked: fan_pass.perks,
            dividend_info: fan_pass.has_dividends? ? {
              rate: fan_pass.dividend_percentage,
              total_earned: nft.total_dividends_earned,
              pending: nft.pending_dividends
            } : nil
          }
        else
          {
            owned: false,
            can_purchase: !fan_pass.sold_out?,
            available_supply: fan_pass.available_supply
          }
        end
      end
    end
  end
end

