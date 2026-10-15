class CommentsController < ApplicationController
  before_action :set_post
  before_action :set_comment, only: [:update, :destroy]

  def index
    comments = @post.comments.order(created_at: :desc)
    render json: CommentSerializer.new(comments).serialize, status: :ok
  end

  def create
    comment = @post.comments.build(comment_params.merge(user: current_user))
    if comment.save
      render json: CommentSerializer.new(comment).serialize, status: :created
    else
      render json: { errors: comment.errors.full_messages }, status: :unprocessable_content
    end
  end

  def update
    if @comment.update(comment_params)
      render json: CommentSerializer.new(@comment).serialize, status: :ok
    else
      render json: { errors: @comment.errors.full_messages }, status: :unprocessable_content
    end
  end

  def destroy
    @comment.destroy
    head :no_content
  end

  private

  def set_post
    @post = Post.find(params[:post_id])
  end

  def set_comment
    @comment = @post.comments.find_by!(id: params[:id], user: current_user)
  end

  def comment_params
    params.expect(comment: [:body])
  end
end
