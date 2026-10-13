class SessionsController < ApplicationController
  skip_before_action :authenticate_user!, only: :create

  def create
    user = User.authenticate_by(email: params[:email], password: params[:password])
    if user
      token = issue_token(user)
      render json: { token: token }, status: :ok
    else
      render json: { error: "Invalid email or password" }, status: :unauthorized
    end
  end
end
