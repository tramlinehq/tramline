class AddCommitToSignOffs < ActiveRecord::Migration[7.0]
  def change
    add_reference :sign_offs, :releases_commit, null: false, foreign_key: true, type: :uuid
  end
end
