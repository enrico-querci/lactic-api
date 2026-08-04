class CreateClientInvitations < ActiveRecord::Migration[8.1]
  def change
    create_table :client_invitations do |t|
      t.references :coach, null: false, foreign_key: { to_table: :users }
      t.string :email, null: false
      t.string :token_digest, null: false
      t.datetime :expires_at, null: false
      t.datetime :sent_at
      t.datetime :accepted_at
      t.datetime :revoked_at

      t.timestamps
    end

    add_index :client_invitations, :token_digest, unique: true
    add_index :client_invitations, %i[coach_id email],
      unique: true,
      where: "accepted_at IS NULL AND revoked_at IS NULL",
      name: "index_pending_client_invitations_on_coach_and_email"
  end
end
