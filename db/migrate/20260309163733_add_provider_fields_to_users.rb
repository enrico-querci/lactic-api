class AddProviderFieldsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :provider, :string
    add_column :users, :provider_uid, :string

    add_index :users, %i[provider provider_uid], unique: true
  end
end
