class PostSerializer
  include Alba::Resource

  attributes :id, :title, :body, :published, :created_at

  attribute :comments_count do |post|
    post.comments.count
  end

  one :user, key: :author, resource: UserSerializer
  many :comments, resource: CommentSerializer
end
