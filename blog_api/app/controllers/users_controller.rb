class UsersController < ApplicationController
  skip_before_action :authenticate_user!, only: :create

  def create
    user = User.new(user_params)
    if user.save
      render json: { user: user.as_json(only: [:id, :name, :email]), token: issue_token(user) }, status: :created
    else
      render json: { errors: user.errors.full_messages }, status: :unprocessable_content
    end
  end

  def me
    render json: current_user.as_json(only: [:id, :name, :email]), status: :ok
  end

  private

  def user_params
    params.expect(user: [:name, :email, :password])
  end
end
