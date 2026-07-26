ActiveRecord::Schema.define do
  # `Workspace` stands in for whatever the host app's owner concept is
  # (Account, Team, User, ...) — proves Llm::Owned doesn't assume "Account".
  create_table :workspaces, force: true do |t|
    t.string :name
  end

  create_table :llm_credentials, force: true do |t|
    t.references :owner, polymorphic: true, null: false
    t.string :provider, null: false
    t.string :model, null: false
    t.text :api_key, null: false
    t.integer :position, null: false
    t.string :task_type, null: false, default: "default"

    t.timestamps
  end
  add_index :llm_credentials, [ :owner_type, :owner_id, :task_type, :position ], unique: true, name: "index_llm_credentials_on_owner_task_type_and_position"

  create_table :llm_usage_records, force: true do |t|
    t.references :owner, polymorphic: true, null: false
    t.string :provider, null: false
    t.string :model, null: false
    t.integer :input_tokens, null: false
    t.integer :output_tokens, null: false
    t.decimal :cost_usd, precision: 12, scale: 6
    t.boolean :shared, null: false, default: false

    t.timestamps
  end
  add_index :llm_usage_records, [ :owner_type, :owner_id, :created_at ], name: "index_llm_usage_records_on_owner_and_created_at"
  add_index :llm_usage_records, [ :owner_type, :owner_id, :provider, :model ], name: "index_llm_usage_records_on_owner_and_provider_and_model"
end
