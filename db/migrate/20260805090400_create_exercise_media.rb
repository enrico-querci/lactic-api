# Media references for an exercise.
#
# `kind` is generic on purpose. The database and the API contract must not be
# coupled to a property named gif_url: v1 ships animations, but images and
# video are expected later.
#
# `provider_url` is never serialized to a client. Stage 4 exposes a Lactic
# endpoint that authenticates upstream and streams the bytes, because the
# provider's media URLs live on the API host and return 401 without the
# server-side key.
class CreateExerciseMedia < ActiveRecord::Migration[8.1]
  def change
    create_table :exercise_media do |t|
      t.references :exercise, null: false, foreign_key: true
      t.string :kind, null: false, default: "animation"
      t.string :mime_type
      t.string :provider_url
      t.string :provider_media_uid
      t.integer :position, null: false, default: 1

      # Populated opportunistically by the importer; all optional because the
      # provider does not report them and they require fetching the bytes.
      t.integer :width
      t.integer :height
      t.bigint :byte_size
      t.string :checksum

      t.string :attribution
      t.string :license

      t.timestamps
    end

    add_index :exercise_media, %i[exercise_id kind position], unique: true

    add_check_constraint :exercise_media,
      "kind IN ('animation', 'image', 'video')",
      name: "exercise_media_kind"

    add_check_constraint :exercise_media,
      "position > 0",
      name: "exercise_media_position_positive"
  end
end
