-- CreateEnum
CREATE TYPE "global_role" AS ENUM ('SUPERADMIN', 'CUSTOMER', 'AUTHENTICATED');

-- CreateEnum
CREATE TYPE "user_type" AS ENUM ('BUSINESS', 'PERSONAL');

-- CreateEnum
CREATE TYPE "phone_number_type" AS ENUM ('CELL', 'OFFICE', 'HOME', 'OTHER');

-- CreateEnum
CREATE TYPE "NotificationType" AS ENUM ('PHOTO_READY', 'TRAINING_READY', 'ANNOUNCEMENT');

-- CreateEnum
CREATE TYPE "user_event_types" AS ENUM ('SIGN_UP', 'SIGN_IN', 'PASSWORD_CHANGE', 'PROFILE_UPDATE', 'DELETE_REQUEST');

-- CreateEnum
CREATE TYPE "organization_role" AS ENUM ('UNAUTHORIZED', 'OWNER', 'ADMIN', 'USER', 'GUEST');

-- CreateEnum
CREATE TYPE "subscription_status" AS ENUM ('ACTIVE', 'INACTIVE');

-- CreateEnum
CREATE TYPE "debit_type" AS ENUM ('TRAINING', 'PROMPT', 'SUBSCRIPTION', 'CHARGEBACK', 'REFUND');

-- CreateEnum
CREATE TYPE "payment_provider" AS ENUM ('STRIPE', 'PAYPAL', 'COINBASE');

-- CreateEnum
CREATE TYPE "payment_type" AS ENUM ('SUBSCRIPTION', 'CREDITS');

-- CreateEnum
CREATE TYPE "address_type" AS ENUM ('POSTAL', 'BILLING', 'GENERAL');

-- CreateEnum
CREATE TYPE "token_type" AS ENUM ('RESET_PASSWORD', 'CHANGE_EMAIL', 'LOGIN_2FA', 'API_KEY');

-- CreateEnum
CREATE TYPE "log_severity" AS ENUM ('TRACE', 'DEBUG', 'INFO', 'WARN', 'ERROR', 'CRITICAL', 'NONE');

-- CreateTable
CREATE TABLE "email_domain_blocklist" (
    "id" SERIAL NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "domain_name" TEXT NOT NULL,

    CONSTRAINT "email_domain_blocklist_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "users" (
    "id" SERIAL NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,
    "confirmed_at" TIMESTAMPTZ(3),
    "display_name" VARCHAR(120),
    "email" VARCHAR(320) NOT NULL,
    "hashed_password" VARCHAR(255),
    "user_role" "global_role" NOT NULL DEFAULT 'CUSTOMER',
    "type_" "user_type" NOT NULL DEFAULT 'PERSONAL',
    "stripe_customer_id" TEXT,
    "referral_id" INTEGER,

    CONSTRAINT "users_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "profiles" (
    "id" SERIAL NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,
    "full_name" VARCHAR(255),
    "secondary_email" VARCHAR(320),
    "business_name" VARCHAR(255),
    "country" VARCHAR(2),
    "position_" VARCHAR(255),
    "mobile_phone_number" VARCHAR(32),
    "phone_number" VARCHAR(32),
    "phone_number_type" "phone_number_type",
    "secondary_phone_number" VARCHAR(32),
    "secondary_phone_number_type" "phone_number_type",
    "user_id" INTEGER NOT NULL,

    CONSTRAINT "profiles_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "users_notifications" (
    "id" SERIAL NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,
    "user_id" INTEGER NOT NULL,
    "type_" "NotificationType" NOT NULL,
    "details" JSONB NOT NULL,

    CONSTRAINT "users_notifications_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "users_preferences" (
    "id" SERIAL NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,
    "allow_email_announcements" BOOLEAN,
    "user_id" INTEGER NOT NULL,

    CONSTRAINT "users_preferences_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "user_events" (
    "id" SERIAL NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "type" "user_event_types" NOT NULL,
    "ip_address" INET NOT NULL,
    "details" JSONB NOT NULL,
    "user_id" INTEGER NOT NULL,

    CONSTRAINT "user_events_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "organizations" (
    "id" SERIAL NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,
    "organization_name" TEXT NOT NULL,

    CONSTRAINT "organizations_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "organization_members" (
    "id" SERIAL NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,
    "org_role" "organization_role" NOT NULL,
    "can_train" BOOLEAN NOT NULL DEFAULT false,
    "invited_name" VARCHAR(255),
    "invited_email" VARCHAR(320),
    "organization_id" INTEGER NOT NULL,
    "user_id" INTEGER,

    CONSTRAINT "organization_members_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "addresses" (
    "id" SERIAL NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,
    "address1" VARCHAR(120),
    "address2" VARCHAR(120),
    "city" TEXT,
    "state_id" INTEGER,
    "countryCode" VARCHAR(2) NOT NULL,
    "postal_code" VARCHAR(16),

    CONSTRAINT "addresses_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "users_addresses" (
    "id" SERIAL NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,
    "type_" "address_type" NOT NULL DEFAULT 'GENERAL',
    "is_primary" BOOLEAN NOT NULL,
    "user_id" INTEGER NOT NULL,
    "address_id" INTEGER NOT NULL,

    CONSTRAINT "users_addresses_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "plans" (
    "id" SERIAL NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,
    "plan_name" VARCHAR(255) NOT NULL,
    "stripe_price_id" VARCHAR(64) NOT NULL,
    "price" INTEGER NOT NULL,

    CONSTRAINT "plans_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "subscriptions" (
    "id" SERIAL NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,
    "ended_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "billing_cycle_start_at" TIMESTAMPTZ(3),
    "stripe_subscription_id" VARCHAR(64),
    "plan_id" INTEGER NOT NULL,
    "status" "subscription_status" NOT NULL,
    "user_id" INTEGER NOT NULL,

    CONSTRAINT "subscriptions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "debits" (
    "id" SERIAL NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,
    "amount" DECIMAL(65,30) NOT NULL,
    "type_" "debit_type" NOT NULL,
    "details" JSONB NOT NULL,
    "user_id" INTEGER NOT NULL,
    "payment_id" INTEGER,

    CONSTRAINT "debits_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "payments" (
    "id" SERIAL NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,
    "user_id" INTEGER NOT NULL,
    "amount" DECIMAL(65,30) NOT NULL,
    "provider" "payment_provider" NOT NULL,
    "type_" "payment_type" NOT NULL,
    "details" JSONB,
    "stripe_payment_id" VARCHAR(64),

    CONSTRAINT "payments_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "sessions" (
    "id" SERIAL NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,
    "expires_at" TIMESTAMPTZ(3),
    "handle" VARCHAR(255) NOT NULL,
    "hashed_session_token" VARCHAR(255),
    "anti_csrf_token" VARCHAR(255),
    "public_data" TEXT,
    "private_data" TEXT,
    "user_id" INTEGER,

    CONSTRAINT "sessions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "tokens" (
    "id" SERIAL NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,
    "hashed_token" VARCHAR(255) NOT NULL,
    "type_" "token_type" NOT NULL,
    "expires_at" TIMESTAMPTZ(3),
    "sent_to" TEXT,
    "name" TEXT,
    "user_id" INTEGER NOT NULL,

    CONSTRAINT "tokens_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "installations" (
    "id" SERIAL NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,
    "started_at" TIMESTAMPTZ(3),
    "destroyed_at" TIMESTAMPTZ(3),
    "lock_heartbeat_at" TIMESTAMPTZ(3),
    "lock_owner" UUID,
    "instance_id" UUID,
    "ip_address" VARCHAR(128),
    "os" VARCHAR(255),
    "hardware" JSONB,

    CONSTRAINT "installations_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "installation_logs" (
    "id" SERIAL NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "severity" "log_severity" NOT NULL,
    "details" JSONB NOT NULL,
    "installation_id" INTEGER NOT NULL,

    CONSTRAINT "installation_logs_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "states" (
    "id" SERIAL NOT NULL,
    "state_name" VARCHAR(255) NOT NULL,
    "country_id" INTEGER NOT NULL,
    "country_code" CHAR(2) NOT NULL,
    "fips_code" VARCHAR(8),
    "iso2" VARCHAR(5) NOT NULL,
    "type_" VARCHAR(45),
    "latitude" DECIMAL(10,8),
    "longitude" DECIMAL(11,8),
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3),
    "flag" SMALLINT NOT NULL DEFAULT 1,
    "wikiDataId" VARCHAR(255),

    CONSTRAINT "states_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "countries" (
    "id" SMALLSERIAL NOT NULL,
    "name" VARCHAR(100) NOT NULL,
    "iso3" CHAR(3) NOT NULL,
    "numeric_code" CHAR(3) NOT NULL,
    "iso2" CHAR(2) NOT NULL,
    "phone_code" VARCHAR(255) NOT NULL,
    "capital" VARCHAR(255),
    "currency" VARCHAR(255) NOT NULL,
    "currency_name" VARCHAR(255) NOT NULL,
    "currency_symbol" VARCHAR(255) NOT NULL,
    "tld" VARCHAR(255) NOT NULL,
    "native" VARCHAR(255),
    "region" VARCHAR(255) NOT NULL,
    "subregion" VARCHAR(255) NOT NULL,
    "timezones" JSONB,
    "translations" JSONB,
    "latitude" DECIMAL(10,8) NOT NULL,
    "longitude" DECIMAL(11,8) NOT NULL,
    "emoji" VARCHAR(191) NOT NULL,
    "emojiU" VARCHAR(191) NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,
    "flag" SMALLINT NOT NULL DEFAULT 1,
    "wiki_data_id" VARCHAR(255),
    "adjectival" TEXT,

    CONSTRAINT "countries_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "email_domain_blocklist_domain_name_key" ON "email_domain_blocklist"("domain_name");

-- CreateIndex
CREATE UNIQUE INDEX "users_display_name_key" ON "users"("display_name");

-- CreateIndex
CREATE UNIQUE INDEX "users_email_key" ON "users"("email");

-- CreateIndex
CREATE UNIQUE INDEX "users_stripe_customer_id_key" ON "users"("stripe_customer_id");

-- CreateIndex
CREATE INDEX "users_stripe_customer_id_idx" ON "users"("stripe_customer_id");

-- CreateIndex
CREATE INDEX "users_created_at_idx" ON "users"("created_at");

-- CreateIndex
CREATE UNIQUE INDEX "profiles_user_id_key" ON "profiles"("user_id");

-- CreateIndex
CREATE INDEX "profiles_user_id_idx" ON "profiles"("user_id");

-- CreateIndex
CREATE INDEX "profiles_created_at_idx" ON "profiles"("created_at");

-- CreateIndex
CREATE INDEX "users_notifications_user_id_idx" ON "users_notifications"("user_id");

-- CreateIndex
CREATE INDEX "users_notifications_created_at_idx" ON "users_notifications"("created_at");

-- CreateIndex
CREATE UNIQUE INDEX "users_preferences_user_id_key" ON "users_preferences"("user_id");

-- CreateIndex
CREATE INDEX "user_events_user_id_idx" ON "user_events"("user_id");

-- CreateIndex
CREATE INDEX "user_events_created_at_idx" ON "user_events"("created_at");

-- CreateIndex
CREATE INDEX "organization_members_user_id_idx" ON "organization_members"("user_id");

-- CreateIndex
CREATE INDEX "organization_members_created_at_idx" ON "organization_members"("created_at");

-- CreateIndex
CREATE UNIQUE INDEX "organization_members_organization_id_invited_email_user_id_key" ON "organization_members"("organization_id", "invited_email", "user_id");

-- CreateIndex
CREATE INDEX "users_addresses_user_id_idx" ON "users_addresses"("user_id");

-- CreateIndex
CREATE UNIQUE INDEX "users_addresses_user_id_type__is_primary_key" ON "users_addresses"("user_id", "type_", "is_primary");

-- CreateIndex
CREATE UNIQUE INDEX "plans_stripe_price_id_key" ON "plans"("stripe_price_id");

-- CreateIndex
CREATE UNIQUE INDEX "subscriptions_stripe_subscription_id_key" ON "subscriptions"("stripe_subscription_id");

-- CreateIndex
CREATE INDEX "subscriptions_user_id_idx" ON "subscriptions"("user_id");

-- CreateIndex
CREATE INDEX "subscriptions_created_at_idx" ON "subscriptions"("created_at");

-- CreateIndex
CREATE INDEX "debits_user_id_idx" ON "debits"("user_id");

-- CreateIndex
CREATE INDEX "debits_created_at_idx" ON "debits"("created_at");

-- CreateIndex
CREATE INDEX "debits_payment_id_idx" ON "debits"("payment_id");

-- CreateIndex
CREATE INDEX "payments_user_id_idx" ON "payments"("user_id");

-- CreateIndex
CREATE INDEX "payments_created_at_idx" ON "payments"("created_at");

-- CreateIndex
CREATE INDEX "payments_stripe_payment_id_idx" ON "payments"("stripe_payment_id");

-- CreateIndex
CREATE UNIQUE INDEX "sessions_handle_key" ON "sessions"("handle");

-- CreateIndex
CREATE INDEX "sessions_user_id_idx" ON "sessions"("user_id");

-- CreateIndex
CREATE INDEX "sessions_created_at_idx" ON "sessions"("created_at");

-- CreateIndex
CREATE INDEX "sessions_expires_at_idx" ON "sessions"("expires_at");

-- CreateIndex
CREATE UNIQUE INDEX "tokens_hashed_token_type__key" ON "tokens"("hashed_token", "type_");

-- CreateIndex
CREATE INDEX "installations_instance_id_idx" ON "installations"("instance_id");

-- CreateIndex
CREATE UNIQUE INDEX "states_country_id_state_name_type__key" ON "states"("country_id", "state_name", "type_");

-- CreateIndex
CREATE UNIQUE INDEX "countries_name_key" ON "countries"("name");

-- CreateIndex
CREATE UNIQUE INDEX "countries_iso3_key" ON "countries"("iso3");

-- CreateIndex
CREATE UNIQUE INDEX "countries_iso2_key" ON "countries"("iso2");

-- AddForeignKey
ALTER TABLE "users" ADD CONSTRAINT "users_referral_id_fkey" FOREIGN KEY ("referral_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "profiles" ADD CONSTRAINT "profiles_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "users_notifications" ADD CONSTRAINT "users_notifications_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "users_preferences" ADD CONSTRAINT "users_preferences_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "user_events" ADD CONSTRAINT "user_events_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "organization_members" ADD CONSTRAINT "organization_members_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "organization_members" ADD CONSTRAINT "organization_members_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "addresses" ADD CONSTRAINT "addresses_state_id_fkey" FOREIGN KEY ("state_id") REFERENCES "states"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "addresses" ADD CONSTRAINT "addresses_countryCode_fkey" FOREIGN KEY ("countryCode") REFERENCES "countries"("iso2") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "users_addresses" ADD CONSTRAINT "users_addresses_address_id_fkey" FOREIGN KEY ("address_id") REFERENCES "addresses"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "users_addresses" ADD CONSTRAINT "users_addresses_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "subscriptions" ADD CONSTRAINT "subscriptions_plan_id_fkey" FOREIGN KEY ("plan_id") REFERENCES "plans"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "subscriptions" ADD CONSTRAINT "subscriptions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "debits" ADD CONSTRAINT "debits_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "debits" ADD CONSTRAINT "debits_payment_id_fkey" FOREIGN KEY ("payment_id") REFERENCES "payments"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "payments" ADD CONSTRAINT "payments_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "sessions" ADD CONSTRAINT "sessions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "tokens" ADD CONSTRAINT "tokens_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "installation_logs" ADD CONSTRAINT "installation_logs_installation_id_fkey" FOREIGN KEY ("installation_id") REFERENCES "installations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "states" ADD CONSTRAINT "states_country_id_fkey" FOREIGN KEY ("country_id") REFERENCES "countries"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
