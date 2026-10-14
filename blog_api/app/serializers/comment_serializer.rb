class CommentSerializer
  include Alba::Resource

  attributes :id, :body, :created_at

  one :user, key: :author, resource: UserSerializer
end
