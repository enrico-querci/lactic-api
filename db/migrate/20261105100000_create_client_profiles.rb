# A coach's own record of a client: the few things worth knowing about someone
# you train, kept apart from the sign-in account. It exists before the person
# does (prepared, then invited) and is linked to their user when they accept
# the invitation, so a coach can set a client up before inviting them.
#
# Not counted against the plan's client limit: a profile gives no access, and
# only an invitation takes a slot (User#client_slots_used).
class CreateClientProfiles < ActiveRecord::Migration[8.1]
  def up
    create_table :client_profiles do |t|
      t.references :coach, null: false, foreign_key: { to_table: :users }
      t.references :user, foreign_key: true, index: { unique: true }
      t.string :name, null: false
      t.string :email
      t.string :phone
      t.string :level
      t.string :goal
      t.text :limitations
      t.text :notes

      t.timestamps
    end
    add_index :client_profiles, "coach_id, LOWER(email)",
              unique: true, where: "email IS NOT NULL",
              name: "index_client_profiles_on_coach_and_lower_email"

    # Every existing client gets a profile, so the coach's list is complete
    # from the start. Invitations still pending have none until accepted.
    execute <<~SQL.squish
      INSERT INTO client_profiles (coach_id, user_id, name, email, created_at, updated_at)
      SELECT coach_id, id, name, LOWER(email), NOW(), NOW()
      FROM users
      WHERE role = 'client' AND coach_id IS NOT NULL
    SQL
  end

  def down
    drop_table :client_profiles
  end
end
