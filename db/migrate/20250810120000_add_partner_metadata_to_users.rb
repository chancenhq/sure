class AddPartnerMetadataToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :partner_metadata, :jsonb, default: {}, null: true
  end
end
