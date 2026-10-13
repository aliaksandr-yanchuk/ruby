class ChangeCommentsBodyNull < ActiveRecord::Migration[8.1]
  def change
    change_column_null :comments, :body, false
  end
end
