module Api
  module V1
    class UsersController < BaseController
      skip_authorization_check

      # GET /api/v1/users/notification_preferences
      def notification_preferences
        render json: {
          preferences: current_user.notification_preferences || default_preferences
        }
      end

      # PATCH /api/v1/users/notification_preferences
      def update_notification_preferences
        current_user.update!(notification_preferences: params[:preferences])
        render json: {
          message: 'Notification preferences updated',
          preferences: current_user.notification_preferences
        }
      rescue => e
        render json: { error: 'Failed to update preferences', details: e.message }, status: :unprocessable_entity
      end

      # DELETE /api/v1/users/account
      def destroy_account
        # Verify password for email users
        if current_user.has_email_auth?
          unless current_user.valid_password?(params[:password])
            return render json: { error: 'Invalid password' }, status: :unauthorized
          end
        end

        # TODO: Add wallet signature verification for wallet users

        # Soft delete (mark as deleted)
        current_user.update!(
          deleted_at: Time.current,
          email: "deleted_#{current_user.id}@deleted.com" if current_user.email,
          wallet_address: nil
        )

        render json: {
          message: 'Account deleted successfully',
          note: 'Your data will be permanently removed after 30 days'
        }
      rescue => e
        render json: { error: 'Failed to delete account', details: e.message }, status: :unprocessable_entity
      end

      private

      def default_preferences
        {
          email_enabled: true,
          purchases: true,
          followers: true,
          comments: true,
          likes: true,
          livestreams: true
        }
      end
    end
  end
end

