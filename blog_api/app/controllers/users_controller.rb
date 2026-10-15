class UsersController < ApplicationController
  skip_before_action :authenticate_user!, only: :create

  def create
    user = User.new(user_params)
    if user.save
      render json: { user: CurrentUserSerializer.new(user).to_h, token: issue_token(user) }, status: :created
    else
      render json: { errors: user.errors.full_messages }, status: :unprocessable_content
    end
  end

  def me
    render json: CurrentUserSerializer.new(current_user).serialize, status: :ok
  end

  private

  def user_params
    params.expect(user: [:name, :email, :password])
  end
end
