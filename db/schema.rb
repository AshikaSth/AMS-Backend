# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_09_22_090231) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "album_artists", force: :cascade do |t|
    t.bigint "album_id", null: false
    t.bigint "artist_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["album_id"], name: "index_album_artists_on_album_id"
    t.index ["artist_id"], name: "index_album_artists_on_artist_id"
  end

  create_table "album_genres", force: :cascade do |t|
    t.bigint "album_id", null: false
    t.bigint "genre_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["album_id"], name: "index_album_genres_on_album_id"
    t.index ["genre_id"], name: "index_album_genres_on_genre_id"
  end

  create_table "album_musics", force: :cascade do |t|
    t.bigint "album_id", null: false
    t.bigint "music_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["album_id"], name: "index_album_musics_on_album_id"
    t.index ["music_id"], name: "index_album_musics_on_music_id"
  end

  create_table "albums", force: :cascade do |t|
    t.string "name"
    t.date "release_date"
    t.string "cover_art_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "artist_id"
    t.index ["artist_id"], name: "index_albums_on_artist_id"
  end

  create_table "artist_genres", force: :cascade do |t|
    t.bigint "artist_id", null: false
    t.bigint "genre_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["artist_id"], name: "index_artist_genres_on_artist_id"
    t.index ["genre_id"], name: "index_artist_genres_on_genre_id"
  end

  create_table "artist_musics", force: :cascade do |t|
    t.bigint "artist_id", null: false
    t.bigint "music_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["artist_id"], name: "index_artist_musics_on_artist_id"
    t.index ["music_id"], name: "index_artist_musics_on_music_id"
  end

  create_table "artists", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.integer "first_release_year"
    t.text "bio"
    t.string "website"
    t.jsonb "social_media_links"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "manager_id"
    t.index ["manager_id"], name: "index_artists_on_manager_id"
    t.index ["user_id"], name: "index_artists_on_user_id"
  end

  create_table "genres", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "music_genres", force: :cascade do |t|
    t.bigint "music_id", null: false
    t.bigint "genre_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["genre_id"], name: "index_music_genres_on_genre_id"
    t.index ["music_id"], name: "index_music_genres_on_music_id"
  end

  create_table "musics", force: :cascade do |t|
    t.string "title"
    t.string "audio_file_url"
    t.string "cover_art_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "artist_id"
  end

  create_table "refresh_tokens", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "token", null: false
    t.datetime "expires_at", null: false
    t.boolean "revoked", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["token"], name: "index_refresh_tokens_on_token", unique: true
    t.index ["user_id"], name: "index_refresh_tokens_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email"
    t.string "password_digest"
    t.integer "role", default: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "first_name"
    t.string "last_name"
    t.string "phone_number"
    t.integer "gender", default: 0
    t.string "address"
    t.date "dob"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "album_artists", "albums"
  add_foreign_key "album_artists", "artists"
  add_foreign_key "album_genres", "albums"
  add_foreign_key "album_genres", "genres"
  add_foreign_key "album_musics", "albums"
  add_foreign_key "album_musics", "musics"
  add_foreign_key "artist_genres", "artists"
  add_foreign_key "artist_genres", "genres"
  add_foreign_key "artist_musics", "artists"
  add_foreign_key "artist_musics", "musics"
  add_foreign_key "artists", "users"
  add_foreign_key "artists", "users", column: "manager_id"
  add_foreign_key "music_genres", "genres"
  add_foreign_key "music_genres", "musics"
  add_foreign_key "refresh_tokens", "users"
end
