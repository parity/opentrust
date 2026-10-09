class AddTermsAcceptanceToMerchants < ActiveRecord::Migration[7.1]
  def change
    add_column :merchants, :terms_accepted_at, :datetime
    add_column :merchants, :terms_version, :string
    add_column :merchants, :terms_accepted_ip, :string
  end
end
