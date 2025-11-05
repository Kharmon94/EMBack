module Api
  module V1
    class FollowsController < BaseController
      # POST /api/v1/artists/:id/follow
      def create
        artist = Artist.find(params[:id])
        
        # Check if already following
        existing_follow = Follow.find_by(
          user: current_user, 
          followable_type: 'Artist',
          followable_id: artist.id
        )
        if existing_follow
          return render json: { 
            message: 'Already following this artist',
            is_following: true 
          }, status: :ok
        end
        
        # Create follow relationship
        follow = current_user.follows.build(
          followable: artist
        )
        
        if follow.save
          # Send notification to artist
          if artist.user && artist.user.id != current_user.id
            notification = Notification.create_follower_notification(artist.user, current_user)
            NotificationChannel.broadcast_to_user(artist.user, notification)
          end
          
          render json: {
            message: 'Successfully followed artist',
            is_following: true,
            followers_count: artist.follows.count
          }, status: :created
        else
          render json: { errors: follow.errors }, status: :unprocessable_entity
        end
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Artist not found' }, status: :not_found
      end
      
      # DELETE /api/v1/artists/:id/follow
      def destroy
        artist = Artist.find(params[:id])
        
        follow = Follow.find_by(
          user: current_user,
          followable_type: 'Artist',
          followable_id: artist.id
        )
        
        if follow
          follow.destroy
          render json: {
            message: 'Successfully unfollowed artist',
            is_following: false,
            followers_count: artist.follows.count
          }
        else
          render json: { error: 'Not following this artist' }, status: :not_found
        end
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Artist not found' }, status: :not_found
      end
      
      # GET /api/v1/users/:id/following
      def following
        user = User.find(params[:id])
        follows = user.follows.where(followable_type: 'Artist')
                     .includes(:followable)
                     .order(created_at: :desc)
        
        render json: {
          following: follows.map { |follow|
            artist = follow.followable
            {
              id: artist.id,
              name: artist.name,
              avatar_url: artist.avatar_url,
              verified: artist.verified,
              followed_at: follow.created_at
            }
          },
          count: follows.count
        }
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'User not found' }, status: :not_found
      end
      
      # GET /api/v1/artists/:id/followers
      def followers
        artist = Artist.find(params[:id])
        follows = artist.follows.includes(:user).order(created_at: :desc).limit(100)
        
        render json: {
          followers: follows.map { |follow|
            {
              wallet_address: follow.user.wallet_address,
              display_name: follow.user.display_name,
              avatar_url: follow.user.avatar_url,
              followed_at: follow.created_at
            }
          },
          count: artist.follows.count
        }
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Artist not found' }, status: :not_found
      end
    end
  end
end

