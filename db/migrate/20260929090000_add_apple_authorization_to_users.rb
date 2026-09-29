# The Sign in with Apple refresh token this app revokes when the account is
# deleted, as App Review guideline 5.1.1(v) requires, and the bundle ID it
# was issued to — Apple only accepts a revocation from that same client.
# See Auth::AppleAuthorization for why it is not encrypted.
class AddAppleAuthorizationToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :apple_refresh_token, :string
    add_column :users, :apple_client_id, :string
  end
end
