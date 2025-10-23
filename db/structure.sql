CREATE TABLE IF NOT EXISTS "schema_migrations" ("version" varchar NOT NULL PRIMARY KEY);
CREATE TABLE IF NOT EXISTS "ar_internal_metadata" ("key" varchar NOT NULL PRIMARY KEY, "value" varchar, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE TABLE IF NOT EXISTS "accounts" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "name" varchar NOT NULL, "join_code" varchar NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "custom_styles" text, "active" boolean DEFAULT 1);
CREATE TABLE IF NOT EXISTS "action_text_rich_texts" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "name" varchar NOT NULL, "body" text, "record_type" varchar NOT NULL, "record_id" bigint NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE UNIQUE INDEX "index_action_text_rich_texts_uniqueness" ON "action_text_rich_texts" ("record_type", "record_id", "name");
CREATE TABLE IF NOT EXISTS "active_storage_blobs" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "key" varchar NOT NULL, "filename" varchar NOT NULL, "content_type" varchar, "metadata" text, "service_name" varchar NOT NULL, "byte_size" bigint NOT NULL, "checksum" varchar, "created_at" datetime(6) NOT NULL);
CREATE UNIQUE INDEX "index_active_storage_blobs_on_key" ON "active_storage_blobs" ("key");
CREATE TABLE IF NOT EXISTS "memberships" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "room_id" integer NOT NULL, "user_id" integer NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "unread_at" datetime(6), "involvement" varchar DEFAULT 'mentions', "connections" integer DEFAULT 0 NOT NULL, "connected_at" datetime(6), "active" boolean DEFAULT 1, "notified_until" datetime(6));
CREATE INDEX "index_memberships_on_room_id_and_created_at" ON "memberships" ("room_id", "created_at");
CREATE UNIQUE INDEX "index_memberships_on_room_id_and_user_id" ON "memberships" ("room_id", "user_id");
CREATE INDEX "index_memberships_on_room_id" ON "memberships" ("room_id");
CREATE INDEX "index_memberships_on_user_id" ON "memberships" ("user_id");
CREATE TABLE IF NOT EXISTS "active_storage_attachments" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "name" varchar NOT NULL, "record_type" varchar NOT NULL, "record_id" bigint NOT NULL, "blob_id" bigint NOT NULL, "created_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_c3b3935057"
FOREIGN KEY ("blob_id")
  REFERENCES "active_storage_blobs" ("id")
);
CREATE INDEX "index_active_storage_attachments_on_blob_id" ON "active_storage_attachments" ("blob_id");
CREATE UNIQUE INDEX "index_active_storage_attachments_uniqueness" ON "active_storage_attachments" ("record_type", "record_id", "name", "blob_id");
CREATE TABLE IF NOT EXISTS "active_storage_variant_records" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "blob_id" bigint NOT NULL, "variation_digest" varchar NOT NULL, CONSTRAINT "fk_rails_993965df05"
FOREIGN KEY ("blob_id")
  REFERENCES "active_storage_blobs" ("id")
);
CREATE UNIQUE INDEX "index_active_storage_variant_records_uniqueness" ON "active_storage_variant_records" ("blob_id", "variation_digest");
CREATE TABLE IF NOT EXISTS "boosts" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "message_id" integer NOT NULL, "booster_id" integer NOT NULL, "content" varchar(16) NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "active" boolean DEFAULT 1, CONSTRAINT "fk_rails_3539c52d73"
FOREIGN KEY ("message_id")
  REFERENCES "messages" ("id")
);
CREATE INDEX "index_boosts_on_booster_id" ON "boosts" ("booster_id");
CREATE INDEX "index_boosts_on_message_id" ON "boosts" ("message_id");
CREATE TABLE IF NOT EXISTS "push_subscriptions" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "user_id" integer NOT NULL, "endpoint" varchar DEFAULT NULL, "p256dh_key" varchar DEFAULT NULL, "auth_key" varchar DEFAULT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "user_agent" varchar DEFAULT NULL, CONSTRAINT "fk_rails_43d43720fc"
FOREIGN KEY ("user_id")
  REFERENCES "users" ("id")
);
CREATE INDEX "idx_on_endpoint_p256dh_key_auth_key_7553014576" ON "push_subscriptions" ("endpoint", "p256dh_key", "auth_key");
CREATE INDEX "index_push_subscriptions_on_user_id" ON "push_subscriptions" ("user_id");
CREATE VIRTUAL TABLE message_search_index using fts5(body, tokenize=porter)
/* message_search_index(body) */;
CREATE TABLE IF NOT EXISTS 'message_search_index_data'(id INTEGER PRIMARY KEY, block BLOB);
CREATE TABLE IF NOT EXISTS 'message_search_index_idx'(segid, term, pgno, PRIMARY KEY(segid, term)) WITHOUT ROWID;
CREATE TABLE IF NOT EXISTS 'message_search_index_content'(id INTEGER PRIMARY KEY, c0);
CREATE TABLE IF NOT EXISTS 'message_search_index_docsize'(id INTEGER PRIMARY KEY, sz BLOB);
CREATE TABLE IF NOT EXISTS 'message_search_index_config'(k PRIMARY KEY, v) WITHOUT ROWID;
CREATE TABLE IF NOT EXISTS "sessions" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "user_id" integer NOT NULL, "token" varchar NOT NULL, "ip_address" varchar, "user_agent" varchar, "last_active_at" datetime(6) NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_758836b4f0"
FOREIGN KEY ("user_id")
  REFERENCES "users" ("id")
);
CREATE INDEX "index_sessions_on_user_id" ON "sessions" ("user_id");
CREATE UNIQUE INDEX "index_sessions_on_token" ON "sessions" ("token");
CREATE TABLE IF NOT EXISTS "webhooks" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "user_id" integer NOT NULL, "url" varchar, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "receives" varchar, CONSTRAINT "fk_rails_51bf96d3bc"
FOREIGN KEY ("user_id")
  REFERENCES "users" ("id")
);
CREATE INDEX "index_webhooks_on_user_id" ON "webhooks" ("user_id");
CREATE TABLE IF NOT EXISTS "rooms" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "name" varchar DEFAULT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "type" varchar NOT NULL, "creator_id" bigint NOT NULL, "messages_count" integer DEFAULT 0, "parent_message_id" integer DEFAULT NULL, "last_active_at" datetime(6), "active" boolean DEFAULT 1, "sortable_name" varchar, "slug" varchar, CONSTRAINT "fk_rails_76a8fc443c"
FOREIGN KEY ("parent_message_id")
  REFERENCES "messages" ("id")
);
CREATE INDEX "index_rooms_on_parent_message_id" ON "rooms" ("parent_message_id");
CREATE TABLE IF NOT EXISTS "bookmarks" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "user_id" integer NOT NULL, "message_id" integer NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "active" boolean DEFAULT 1, CONSTRAINT "fk_rails_c1ff6fa4ac"
FOREIGN KEY ("user_id")
  REFERENCES "users" ("id")
, CONSTRAINT "fk_rails_ff39da9a98"
FOREIGN KEY ("message_id")
  REFERENCES "messages" ("id")
);
CREATE INDEX "index_bookmarks_on_user_id" ON "bookmarks" ("user_id");
CREATE INDEX "index_bookmarks_on_message_id" ON "bookmarks" ("message_id");
CREATE TABLE IF NOT EXISTS "auth_tokens" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "user_id" integer NOT NULL, "token" varchar, "code" varchar, "expires_at" datetime(6), "used_at" datetime(6), "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_0d66c22f4c"
FOREIGN KEY ("user_id")
  REFERENCES "users" ("id")
);
CREATE INDEX "index_auth_tokens_on_user_id" ON "auth_tokens" ("user_id");
CREATE TABLE IF NOT EXISTS "searches" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "user_id" integer NOT NULL, "query" varchar NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "creator_id" integer DEFAULT NULL, CONSTRAINT "fk_rails_e192b86393"
FOREIGN KEY ("user_id")
  REFERENCES "users" ("id")
, CONSTRAINT "fk_rails_a00933ab4f"
FOREIGN KEY ("creator_id")
  REFERENCES "users" ("id")
);
CREATE INDEX "index_searches_on_user_id" ON "searches" ("user_id");
CREATE INDEX "index_searches_on_creator_id" ON "searches" ("creator_id");
CREATE TABLE IF NOT EXISTS "users" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "name" varchar NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "role" integer DEFAULT 0 NOT NULL, "email_address" varchar DEFAULT NULL, "password_digest" varchar DEFAULT NULL, "active" boolean DEFAULT 1, "bio" text DEFAULT NULL, "avatar_url" varchar DEFAULT NULL, "twitter_username" varchar DEFAULT NULL, "linkedin_username" varchar DEFAULT NULL, "personal_url" varchar DEFAULT NULL, "membership_started_at" datetime(6) DEFAULT NULL, "bot_token" varchar DEFAULT NULL, "ascii_name" varchar DEFAULT NULL, "twitter_url" varchar DEFAULT NULL, "linkedin_url" varchar DEFAULT NULL, "order_id" bigint DEFAULT NULL, "suspended_at" datetime(6) DEFAULT NULL, "preferences" text DEFAULT '{}', "last_authenticated_at" datetime(6));
CREATE UNIQUE INDEX "index_users_on_bot_token" ON "users" ("bot_token");
CREATE UNIQUE INDEX "index_users_on_email_address" ON "users" ("email_address");
CREATE UNIQUE INDEX "index_users_on_order_id" ON "users" ("order_id") WHERE order_id IS NOT NULL;
CREATE TABLE IF NOT EXISTS "webhook_events" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "source" varchar, "event_type" varchar, "payload" text, "processed_at" datetime(6), "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE INDEX "index_memberships_on_room_user_involvement" ON "memberships" ("room_id", "user_id", "involvement");
CREATE TABLE IF NOT EXISTS "messages" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "room_id" integer NOT NULL, "creator_id" integer NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "client_message_id" varchar NOT NULL, "active" boolean DEFAULT 1, "answered_at" datetime(6) DEFAULT NULL, "answered_by_id" integer DEFAULT NULL, "mentions_everyone" boolean DEFAULT 0 NOT NULL, CONSTRAINT "fk_rails_761a2f12b3"
FOREIGN KEY ("creator_id")
  REFERENCES "users" ("id")
, CONSTRAINT "fk_rails_a8db0fb63a"
FOREIGN KEY ("room_id")
  REFERENCES "rooms" ("id")
, CONSTRAINT "fk_rails_f7397f9762"
FOREIGN KEY ("answered_by_id")
  REFERENCES "users" ("id")
);
CREATE INDEX "index_messages_on_creator_id" ON "messages" ("creator_id");
CREATE INDEX "index_messages_on_room_id" ON "messages" ("room_id");
CREATE INDEX "index_messages_on_created_at" ON "messages" ("created_at");
CREATE INDEX "index_messages_on_room_id_and_created_at" ON "messages" ("room_id", "created_at");
CREATE INDEX "index_messages_on_answered_at" ON "messages" ("answered_at");
CREATE INDEX "index_messages_on_answered_by_id" ON "messages" ("answered_by_id");
CREATE TABLE IF NOT EXISTS "mailkick_subscriptions" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "subscriber_type" varchar, "subscriber_id" integer, "list" varchar, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE UNIQUE INDEX "index_mailkick_subscriptions_on_subscriber_and_list" ON "mailkick_subscriptions" ("subscriber_type", "subscriber_id", "list");
CREATE TABLE IF NOT EXISTS "mentions" ("user_id" integer NOT NULL, "message_id" integer NOT NULL, CONSTRAINT "fk_rails_df6f108928"
FOREIGN KEY ("message_id")
  REFERENCES "messages" ("id")
, CONSTRAINT "fk_rails_1b711e94aa"
FOREIGN KEY ("user_id")
  REFERENCES "users" ("id")
);
CREATE INDEX "index_mentions_on_user_id" ON "mentions" ("user_id");
CREATE INDEX "index_mentions_on_message_id" ON "mentions" ("message_id");
CREATE INDEX "index_mentions_on_message_id_and_user_id" ON "mentions" ("message_id", "user_id");
CREATE INDEX "index_mentions_on_user_id_and_message_id" ON "mentions" ("user_id", "message_id");
CREATE TABLE IF NOT EXISTS "blocks" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "blocker_id" integer NOT NULL, "blocked_id" integer NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_c0ad31bb25"
FOREIGN KEY ("blocker_id")
  REFERENCES "users" ("id")
, CONSTRAINT "fk_rails_c7fbc30382"
FOREIGN KEY ("blocked_id")
  REFERENCES "users" ("id")
);
CREATE INDEX "index_blocks_on_blocker_id" ON "blocks" ("blocker_id");
CREATE INDEX "index_blocks_on_blocked_id" ON "blocks" ("blocked_id");
CREATE UNIQUE INDEX "index_blocks_on_blocker_id_and_blocked_id" ON "blocks" ("blocker_id", "blocked_id");
CREATE UNIQUE INDEX "index_rooms_on_slug" ON "rooms" ("slug") WHERE slug IS NOT NULL;
CREATE TABLE IF NOT EXISTS "library_classes" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "slug" varchar NOT NULL, "title" varchar NOT NULL, "creator" varchar NOT NULL, "position" integer DEFAULT 0 NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE UNIQUE INDEX "index_library_classes_on_slug" ON "library_classes" ("slug");
CREATE INDEX "index_library_classes_on_position" ON "library_classes" ("position");
CREATE TABLE IF NOT EXISTS "library_categories" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "name" varchar NOT NULL, "slug" varchar NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE UNIQUE INDEX "index_library_categories_on_slug" ON "library_categories" ("slug");
CREATE TABLE IF NOT EXISTS "library_classes_categories" ("library_class_id" integer NOT NULL, "library_category_id" integer NOT NULL, CONSTRAINT "fk_rails_ed72d5b607"
FOREIGN KEY ("library_class_id")
  REFERENCES "library_classes" ("id")
, CONSTRAINT "fk_rails_673d729ea7"
FOREIGN KEY ("library_category_id")
  REFERENCES "library_categories" ("id")
);
CREATE INDEX "index_library_classes_categories_on_library_class_id" ON "library_classes_categories" ("library_class_id");
CREATE INDEX "index_library_classes_categories_on_library_category_id" ON "library_classes_categories" ("library_category_id");
CREATE UNIQUE INDEX "index_library_classes_categories_on_class_and_category" ON "library_classes_categories" ("library_class_id", "library_category_id");
CREATE TABLE IF NOT EXISTS "library_watch_histories" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "library_session_id" integer NOT NULL, "user_id" integer NOT NULL, "played_seconds" integer DEFAULT 0 NOT NULL, "last_watched_at" datetime(6), "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "duration_seconds" integer, "completed" boolean DEFAULT 0 NOT NULL, CONSTRAINT "fk_rails_e5111d59cc"
FOREIGN KEY ("library_session_id")
  REFERENCES "library_sessions" ("id")
, CONSTRAINT "fk_rails_91f2e61b88"
FOREIGN KEY ("user_id")
  REFERENCES "users" ("id")
);
CREATE UNIQUE INDEX "index_library_watch_histories_on_session_and_user" ON "library_watch_histories" ("library_session_id", "user_id");
CREATE TABLE IF NOT EXISTS "library_sessions" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "library_class_id" integer NOT NULL, "vimeo_id" varchar NOT NULL, "vimeo_hash" varchar DEFAULT NULL, "padding" decimal(5,2) DEFAULT 56.25 NOT NULL, "quality" varchar DEFAULT NULL, "position" integer DEFAULT 0 NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "description" text NOT NULL, "played_seconds" integer DEFAULT 0 NOT NULL, "last_watched_at" datetime(6) DEFAULT NULL, "featured" boolean DEFAULT 0 NOT NULL, "featured_position" integer DEFAULT 0 NOT NULL, CONSTRAINT "fk_rails_dd5ecdc6f9"
FOREIGN KEY ("library_class_id")
  REFERENCES "library_classes" ("id")
);
CREATE INDEX "index_library_sessions_on_library_class_id" ON "library_sessions" ("library_class_id");
CREATE INDEX "index_library_sessions_on_vimeo_id" ON "library_sessions" ("vimeo_id");
CREATE INDEX "index_library_sessions_on_position" ON "library_sessions" ("position");
CREATE INDEX "index_library_sessions_on_featured" ON "library_sessions" ("featured");
CREATE INDEX "index_library_sessions_on_featured_position" ON "library_sessions" ("featured_position");
CREATE INDEX "index_messages_on_room_id_and_mentions_everyone" ON "messages" ("room_id", "mentions_everyone") WHERE mentions_everyone = true;
CREATE TABLE IF NOT EXISTS "live_events" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "title" varchar NOT NULL, "url" varchar NOT NULL, "target_time" datetime(6) NOT NULL, "duration_hours" integer DEFAULT 2 NOT NULL, "show_early_hours" integer DEFAULT 24 NOT NULL, "active" boolean DEFAULT 1 NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE INDEX "index_live_events_on_active" ON "live_events" ("active");
CREATE INDEX "index_live_events_on_target_time" ON "live_events" ("target_time");
INSERT INTO "schema_migrations" (version) VALUES
('20251022001753'),
('20251021090000'),
('20251021014520'),
('20251013024845'),
('20251013024703'),
('20251013024645'),
('20251013005410'),
('20251012180000'),
('20251011174948'),
('20251011174942'),
('20251011060050'),
('20251011060045'),
('20250928120000'),
('20250804105525'),
('20250319101929'),
('20250313150105'),
('20250313112520'),
('20250310112527'),
('20250303042704'),
('20241226114337'),
('20241224175056'),
('20241126110407'),
('20241125133852'),
('20241125132029'),
('20241124151653'),
('20241123162248'),
('20241123124521'),
('20241120095425'),
('20241118112348'),
('20241015185114'),
('20241015185107'),
('20241015185058'),
('20241015185047'),
('20241015185038'),
('20241015185028'),
('20240916105936'),
('20240910115400'),
('20240526200606'),
('20240525122726'),
('20240519151155'),
('20240515161105'),
('20240331153313'),
('20240328093042'),
('20240226155214'),
('20240220160705'),
('20240218202254'),
('20240209110503'),
('20240204114557'),
('20240131105830'),
('20240130213001'),
('20240130003150'),
('20240115124901'),
('20240110071740'),
('20231220143106'),
('20231215043540');

