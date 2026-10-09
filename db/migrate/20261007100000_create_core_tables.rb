class CreateCoreTables < ActiveRecord::Migration[7.1]
  def change
    create_table :merchants do |t|
      t.string :name, null: false
      t.string :business_name, null: false
      t.string :website
      t.string :gstin
      t.string :contact_email, null: false
      t.string :phone
      t.string :status, null: false, default: "pending"
      t.bigint :lookup_credits, null: false, default: 0
      t.string :rejection_reason
      t.datetime :approved_at
      t.bigint :approved_by_id
      t.timestamps
    end
    add_index :merchants, :status
    add_index :merchants, :contact_email, unique: true

    create_table :merchant_users do |t|
      t.references :merchant, null: false, foreign_key: true, index: { unique: true }
      t.string :email, null: false
      t.string :password_digest, null: false
      t.timestamps
    end
    add_index :merchant_users, :email, unique: true

    create_table :admin_users do |t|
      t.string :email, null: false
      t.string :password_digest, null: false
      t.timestamps
    end
    add_index :admin_users, :email, unique: true

    create_table :api_keys do |t|
      t.references :merchant, null: false, foreign_key: true
      t.string :key_digest, null: false
      t.string :prefix, null: false
      t.string :label
      t.datetime :last_used_at
      t.datetime :revoked_at
      t.timestamps
    end
    add_index :api_keys, :key_digest, unique: true

    create_table :fraud_reports do |t|
      t.references :merchant, null: false, foreign_key: true
      t.string :phone_hash, null: false
      t.text :phone_ciphertext, null: false
      t.string :phone_last4, null: false
      t.string :reason_code, null: false
      t.string :notes, limit: 500
      t.datetime :incident_at
      t.string :status, null: false, default: "active"
      t.timestamps
    end
    add_index :fraud_reports, [:merchant_id, :phone_hash], unique: true
    add_index :fraud_reports, :phone_hash

    create_table :karma_ledger_entries do |t|
      t.references :merchant, null: false, foreign_key: true
      t.integer :delta_credits, null: false
      t.bigint :balance_after, null: false
      t.string :reason, null: false
      t.string :ref_type
      t.bigint :ref_id
      t.string :memo
      t.datetime :created_at, null: false
    end
    add_index :karma_ledger_entries, [:merchant_id, :created_at]

    create_table :audit_logs do |t|
      t.references :admin_user, foreign_key: true
      t.string :action, null: false
      t.string :target_type
      t.bigint :target_id
      t.jsonb :details, null: false, default: {}
      t.datetime :created_at, null: false
    end
  end
end
