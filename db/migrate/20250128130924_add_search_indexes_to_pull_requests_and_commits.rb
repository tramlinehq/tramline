class AddSearchIndexesToPullRequestsAndCommits < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def up
    enable_extension 'pg_trgm'
    
    add_column :pull_requests, :search_vector, :tsvector
    add_column :commits, :search_vector, :tsvector
    
    # Add GIN indexes for text search fields
    add_index :pull_requests, :title, 
      using: :gin, 
      opclass: :gin_trgm_ops, 
      algorithm: :concurrently
      
    add_index :pull_requests, :body, 
      using: :gin, 
      opclass: :gin_trgm_ops, 
      algorithm: :concurrently
      
    add_index :pull_requests, :search_vector, 
      using: :gin, 
      algorithm: :concurrently
    
    # Commit indexes
    add_index :commits, :message, 
      using: :gin, 
      opclass: :gin_trgm_ops, 
      algorithm: :concurrently
      
    add_index :commits, :search_vector, 
      using: :gin, 
      algorithm: :concurrently
    
    # Generate initial search vectors
    PullRequest.find_each do |pr|
      search_text = [pr.title, pr.body, pr.number.to_s].compact.join(' ')
      pr.update_column :search_vector, PullRequest.generate_search_vector(search_text)
    end
    
    Commit.find_each do |commit|
      commit.update_column :search_vector, Commit.generate_search_vector(commit.message)
    end
  end

  def down
    remove_index :pull_requests, :title, algorithm: :concurrently
    remove_index :pull_requests, :body, algorithm: :concurrently
    remove_index :pull_requests, :search_vector, algorithm: :concurrently
    remove_index :commits, :message, algorithm: :concurrently
    remove_index :commits, :search_vector, algorithm: :concurrently
    
    remove_column :pull_requests, :search_vector
    remove_column :commits, :search_vector
  end
end 