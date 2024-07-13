class AddSso < ActiveRecord::Migration[7.0]
  def change
    safety_assured do
      change_table :organizations, bulk: true do |t|
        t.column :sso, :boolean, default: false
        t.column :sso_tenant_id, :string, default: nil
        t.column :sso_tenant_name, :string, default: nil
        t.column :sso_domains, :string, array: true, default: []
        t.column :sso_protocol, :string, default: nil
        t.column :sso_configuration_link, :string, default: nil
      end
    end

    create_table :user_authentications, id: :uuid do |t|
      t.references :authenticatable, polymorphic: true, index: true, null: false, type: :uuid
      t.belongs_to :user, index: true, foreign_key: true, type: :uuid
      t.timestamps null: false
    end

    create_table :sso_authentications, id: :uuid do |t|
      t.string :login_id, null: false
      t.string :email, null: false, default: ""
      t.datetime :logout_time
      t.datetime :sso_created_time
      t.timestamps null: false
    end
    add_index :sso_authentications, :email, unique: true
    add_index :sso_authentications, :login_id, unique: true

    create_table :email_authentications, id: :uuid do |t|
      ## Database authenticatable
      t.string :email, null: false, default: ""
      t.string :encrypted_password, null: false, default: ""

      ## Recoverable
      t.string :reset_password_token
      t.datetime :reset_password_sent_at

      ## Rememberable
      t.datetime :remember_created_at

      ## Trackable
      t.integer :sign_in_count, default: 0, null: false
      t.datetime :current_sign_in_at
      t.datetime :last_sign_in_at
      t.string :current_sign_in_ip
      t.string :last_sign_in_ip

      ## Confirmable
      t.string :confirmation_token
      t.datetime :confirmed_at
      t.datetime :confirmation_sent_at
      t.string :unconfirmed_email # Only if using reconfirmable

      ## Lockable
      t.integer :failed_attempts, default: 0, null: false # Only if lock strategy is :failed_attempts
      t.string :unlock_token # Only if unlock strategy is :email or :both
      t.datetime :locked_at
      t.timestamps null: false
    end
    add_index :email_authentications, :email, unique: true
    add_index :email_authentications, :reset_password_token, unique: true
    add_index :email_authentications, :confirmation_token, unique: true
    add_index :email_authentications, :unlock_token, unique: true

    # --- SCARY USER MODEL CHANGES ---
    change_column_null :users, :email, true
    change_column_null :users, :encrypted_password, true
    remove_index :users, :email, unique: true
    remove_index :users, :confirmation_token, unique: true
    remove_index :users, :reset_password_token, unique: true
    remove_index :users, :unlock_token, unique: true
  end
end
