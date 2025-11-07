module Api
  module V1
    class PreSavesController < ApplicationController
      before_action :authenticate_user!
      
      # POST /api/v1/pre_saves
      def create
        pre_save = current_user.pre_saves.new(pre_save_params)
        
        if pre_save.save
          render json: { pre_save: pre_save_json(pre_save) }, status: :created
        else
          render json: { errors: pre_save.errors.full_messages }, status: :unprocessable_entity
        end
      end
      
      # DELETE /api/v1/pre_saves/:id
      def destroy
        pre_save = current_user.pre_saves.find(params[:id])
        pre_save.destroy
        head :no_content
      end
      
      # GET /api/v1/pre_saves
      def index
        pre_saves = current_user.pre_saves.includes(:pre_saveable).pending
        render json: { pre_saves: pre_saves.map { |ps| pre_save_json(ps) } }
      end
      
      private
      
      def pre_save_params
        params.require(:pre_save).permit(:pre_saveable_type, :pre_saveable_id, :release_date)
      end
      
      def pre_save_json(pre_save)
        {
          id: pre_save.id,
          pre_saveable_type: pre_save.pre_saveable_type,
          pre_saveable_id: pre_save.pre_saveable_id,
          release_date: pre_save.release_date,
          notified: pre_save.notified,
          converted: pre_save.converted,
          created_at: pre_save.created_at
        }
      end
    end
  end
end

