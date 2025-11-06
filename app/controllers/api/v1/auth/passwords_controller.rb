module Api
  module V1
    module Auth
      class PasswordsController < BaseController
        skip_authorization_check

        # POST /api/v1/auth/change_password
        def change_password
          unless current_user.has_email_auth?
            return render json: { error: 'Password authentication not enabled for this account' }, status: :unprocessable_entity
          end

          unless current_user.valid_password?(params[:current_password])
            return render json: { error: 'Current password is incorrect' }, status: :unauthorized
          end

          if params[:new_password].length < 8
            return render json: { error: 'New password must be at least 8 characters' }, status: :unprocessable_entity
          end

          current_user.update!(password: params[:new_password])
          
          render json: { message: 'Password changed successfully' }
        rescue => e
          render json: { error: 'Failed to change password', details: e.message }, status: :unprocessable_entity
        end
      end
    end
  end
end

