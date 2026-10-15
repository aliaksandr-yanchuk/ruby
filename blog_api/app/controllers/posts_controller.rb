class PostsController < ApplicationController
  before_action :set_post, only: [:update, :destroy]

  def index
    posts = Post.all.order(created_at: :desc)
    render json: PostSerializer.new(posts).serialize, status: :ok
  end

  def show
    render json: PostSerializer.new(Post.find(params[:id])).serialize
  end

  def create
    post = current_user.posts.build(post_params)
    if post.save
      render json: PostSerializer.new(post).serialize, status: :created
    else
      render json: { errors: post.errors.full_messages }, status: :unprocessable_content
    end
  end

  def update
    if @post.update(post_params)
      render json: PostSerializer.new(@post).serialize, status: :ok
    else
      render json: { errors: @post.errors.full_messages }, status: :unprocessable_content
    end
  end

  def destroy
    @post.destroy
    head :no_content
  end

  private

  def set_post
    @post = current_user.posts.find(params[:id])
  end

  def post_params
    params.expect(post: [:title, :body, :published])
  end
end
