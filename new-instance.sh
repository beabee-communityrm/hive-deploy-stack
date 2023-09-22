#!/bin/bash

if [ $# -ne 2 ]; then
        echo "Usage: ./new-instance.sh <name> <domain>"
        exit 1
fi

name=$1
domain=$2

secret=$(pwgen 64)
gc_secret=$(pwgen 128)
nl_secret=$(pwgen 64)

db_name=beabee-$name
db_pass=$(pwgen 64)

cat <<EOF
BEABEE_DOMAIN=$domain
BEABEE_AUDIENCE=https://$domain
BEABEE_DEV=false
BEABEE_SECRET=$secret
BEABEE_COOKIE_DOMAIN=$domain

BEABEE_COUNTRYCODE=de
BEABEE_CURRENCYCODE=EUR
BEABEE_CURRENCYSYMBOL=€

BEABEE_EMAIL_PROVIDER=sendgrid
BEABEE_EMAIL_SETTINGS_APIKEY=SG.???

BEABEE_NEWSLETTER_PROVIDER=none
BEABEE_NEWSLETTER_SETTINGS_APIKEY=???
BEABEE_NEWSLETTER_SETTINGS_DATACENTER=???
BEABEE_NEWSLETTER_SETTINGS_LISTID=???
BEABEE_NEWSLETTER_SETTINGS_WEBHOOKSECRET=$nl_secret

BEABEE_GOCARDLESS_ACCESSTOKEN=???
BEABEE_GOCARDLESS_SECRET=$gc_secret
BEABEE_GOCARDLESS_SANDBOX=false

BEABEE_STRIPE_PUBLICKEY=pk_live_???
BEABEE_STRIPE_SECRETKEY=sk_live_???
BEABEE_STRIPE_WEBHOOKSECRET=whsec_???
BEABEE_STRIPE_MEMBERSHIPPRODUCTID=prod_???
BEABEE_STRIPE_COUNTRY=eu

BEABEE_APPOVERRIDES='{ "projects": { "config": { "disabled": true } }, "settings": { "subApps": { "pages": { "config": { "hidden": true } }, "newsletters": { "config": { "hidden": true } }, "email": { "config": { "hidden": true } }, "options": { "config": { "hidden": true } } } }, "tools": { "subApps": { "referrals": { "config": { "disabled": true } } } }, "polls": { "config": { "menu": "none" } }, "reports": { "config": { "disabled": true } } }'

TYPEORM_URL=postgres://$db_name:$db_pass@postgres-postgres-1-1/$db_name
EOF

echo
echo ===============================================================
echo
echo -- Database initialisation

cat <<EOF
CREATE USER "$db_name" WITH PASSWORD '$db_pass';
CREATE DATABASE "$db_name" WITH OWNER "$db_name";
\c "$db_name"
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
REVOKE ALL ON SCHEMA public FROM PUBLIC;
GRANT ALL ON SCHEMA public TO "$db_name";

CREATE SCHEMA invoices;
CREATE TABLE invoices.payment_seen (
    id VARCHAR PRIMARY KEY,
    added TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

GRANT USAGE ON SCHEMA public TO "beabee-invoices";
GRANT USAGE ON SCHEMA invoices TO "beabee-invoices";

GRANT SELECT, INSERT ON invoices.payment_seen TO "beabee-invoices";

-- Post migration step for invoicing

GRANT SELECT (id, "contributionMonthlyAmount", "contributionType") ON contact TO "beabee-invoices";
GRANT SELECT ON contact_role TO "beabee-invoices";
GRANT SELECT (id, amount, status, "chargeDate") ON payment TO "beabee-invoices";

EOF

echo
echo ===============================================================
echo

cat <<EOF
# DNS records

Type: CNAME
Name: $domain
Value: $name.clients.hive.beabee.io

... add other records

# Secrets

## GoCardless

Webhook URL: https://$domain/webhook/gc
Secret: $gc_secret


## Mailchimp

Webhook URL: https://$domain/webhook/mailchimp?secret=$nl_secret
EOF
