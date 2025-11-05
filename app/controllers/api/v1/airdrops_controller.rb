module Api
  module V1
    class AirdropsController < BaseController
      skip_before_action :authenticate_user!, only: [:index, :show, :proof], raise: false
      load_and_authorize_resource except: [:proof, :claim, :index, :show]
      skip_authorization_check only: [:index, :show, :proof]
      
      # GET /api/v1/airdrops
      def index
        @airdrops = Airdrop.includes(:artist, :artist_token)
        
        # Filter by artist
        @airdrops = @airdrops.where(artist_id: params[:artist_id]) if params[:artist_id]
        
        # Filter by active/ended
        if params[:active] == 'true'
          @airdrops = @airdrops.where('end_date >= ?', Time.current)
        end
        
        @airdrops = @airdrops.order(created_at: :desc)
        @paginated = paginate(@airdrops)
        
        render json: {
          airdrops: @paginated.map { |airdrop| airdrop_json(airdrop) },
          meta: pagination_meta(@airdrops, @paginated)
        }
      end
      
      # GET /api/v1/airdrops/:id
      def show
        render json: {
          airdrop: detailed_airdrop_json(@airdrop),
          claim_status: get_claim_status(@airdrop, current_user)
        }
      end
      
      # POST /api/v1/airdrops
      def create
        @airdrop = current_artist.airdrops.build(airdrop_params)
        
        # TODO: Generate Merkle tree from eligible holders list
        # For now, accept merkle_root from params
        @airdrop.merkle_root = params[:merkle_root]
        
        if @airdrop.save
          # TODO: Create airdrop on Solana using airdrop program
          
          render json: {
            airdrop: detailed_airdrop_json(@airdrop),
            message: 'Airdrop created successfully'
          }, status: :created
        else
          render json: { errors: @airdrop.errors }, status: :unprocessable_entity
        end
      end
      
      # GET /api/v1/airdrops/:id/proof/:wallet_address
      def proof
        @airdrop = Airdrop.find(params[:id])
        wallet_address = params[:wallet_address]
        
        # TODO: Generate Merkle proof for this wallet
        # This would query the stored tree or regenerate
        
        # Placeholder response
        proof = generate_merkle_proof(@airdrop, wallet_address)
        
        render json: {
          eligible: proof[:eligible],
          amount: proof[:amount],
          proof: proof[:proof],
          message: proof[:eligible] ? 'Wallet is eligible' : 'Wallet is not eligible'
        }
      end
      
      # POST /api/v1/airdrops/:id/claim
      def claim
        @airdrop = Airdrop.find(params[:id])
        authorize! :create, AirdropClaim
        
        # Check if already claimed
        existing_claim = AirdropClaim.find_by(airdrop: @airdrop, user: current_user)
        if existing_claim
          return render json: { error: 'Already claimed' }, status: :unprocessable_entity
        end
        
        # Check claim window
        unless Time.current.between?(@airdrop.start_date, @airdrop.end_date)
          return render json: { error: 'Claim window has closed' }, status: :unprocessable_entity
        end
        
        # Verify proof
        amount = params[:amount].to_f
        proof = params[:proof] # Array of hashes
        
        # TODO: Verify Merkle proof
        # TODO: Execute Solana claim transaction
        
        signature = params[:transaction_signature]
        unless signature
          return render json: { error: 'Transaction signature required' }, status: :bad_request
        end
        
        # Record claim
        claim = AirdropClaim.create!(
          airdrop: @airdrop,
          user: current_user,
          amount: amount,
          claimed_at: Time.current,
          transaction_signature: signature
        )
        
        # Update airdrop claimed amount
        @airdrop.increment!(:claimed_amount, amount)
        
        render json: {
          claim: claim_json(claim),
          message: 'Tokens claimed successfully'
        }
      end
      
      private
      
      def airdrop_params
        params.require(:airdrop).permit(
          :artist_token_id, :total_amount, :start_date, :end_date, :program_address
        )
      end
      
      def airdrop_json(airdrop)
        {
          id: airdrop.id,
          total_amount: airdrop.total_amount,
          claimed_amount: airdrop.claimed_amount,
          remaining_amount: airdrop.total_amount - airdrop.claimed_amount,
          start_date: airdrop.start_date,
          end_date: airdrop.end_date,
          is_active: Time.current.between?(airdrop.start_date, airdrop.end_date),
          artist: {
            id: airdrop.artist.id,
            name: airdrop.artist.name
          },
          token: {
            id: airdrop.artist_token.id,
            name: airdrop.artist_token.name,
            symbol: airdrop.artist_token.symbol
          }
        }
      end
      
      def detailed_airdrop_json(airdrop)
        airdrop_json(airdrop).merge(
          merkle_root: airdrop.merkle_root,
          program_address: airdrop.program_address,
          claims_count: airdrop.airdrop_claims.count,
          created_at: airdrop.created_at
        )
      end
      
      def claim_json(claim)
        {
          id: claim.id,
          amount: claim.amount,
          claimed_at: claim.claimed_at,
          transaction_signature: claim.transaction_signature
        }
      end
      
      def get_claim_status(airdrop, user)
        return { claimed: false } unless user
        
        claim = airdrop.airdrop_claims.find_by(user: user)
        if claim
          {
            claimed: true,
            amount: claim.amount,
            claimed_at: claim.claimed_at
          }
        else
          {
            claimed: false
          }
        end
      end
      
      def generate_merkle_proof(airdrop, wallet_address)
        # TODO: Implement actual Merkle proof generation
        # This would:
        # 1. Load the full Merkle tree (stored off-chain or regenerated)
        # 2. Find the leaf for this wallet
        # 3. Generate proof path from leaf to root
        
        # Placeholder
        {
          eligible: false,
          amount: 0,
          proof: [],
          message: 'Merkle proof generation not yet implemented'
        }
      end
    end
  end
end

