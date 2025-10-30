#!/bin/bash

if [ $# -ne 2 ]; then
        echo "Usage: ./new-instance.sh <name> <domain>"
        exit 1
fi

name=$1
domain=$2

secret=$(pwgen 64)
service_secret=$(pwgen 64)
gc_secret=$(pwgen 128)
nl_secret=$(pwgen 64)

db_name=beabee-$name
db_pass=$(pwgen 64)

minio_user=$db_name
minio_bucket=$db_name
minio_secretkey=$(pwgen -y 24)

echo ===============================================================
echo
echo -- Stack environment variables
echo -- Copy these to the new stack in Portainer
echo

cat <<EOF
BEABEE_DOMAIN=$domain
BEABEE_AUDIENCE=https://$domain
BEABEE_DEV=false
BEABEE_SECRET=$secret
BEABEE_SERVICE_SECRET=$service_secret
BEABEE_COOKIE_DOMAIN=$domain

BEABEE_COUNTRYCODE=de
BEABEE_CURRENCYCODE=EUR
BEABEE_CURRENCYSYMBOL=€

BEABEE_APPOVERRIDES='{ "gift": { "config": { "disabled": true } }, "projects": { "config": { "disabled": true } }, "settings": { "subApps": { "pages": { "config": { "hidden": true } }, "newsletters": { "config": { "hidden": true } }, "email": { "config": { "hidden": true } }, "options": { "config": { "hidden": true } } } }, "tools": { "subApps": { "referrals": { "config": { "disabled": true } } } }, "polls": { "config": { "menu": "none" } }, "reports": { "config": { "disabled": true } } }'

BEABEE_DATABASE_URL=postgres://$db_name:$db_pass@postgres-postgres-1-1/$db_name

BEABEE_MINIO_ENDPOINT=http://minio-minio-1:9000
BEABEE_MINIO_BUCKET=$minio_bucket
BEABEE_MINIO_ACCESSKEY=$minio_user
BEABEE_MINIO_SECRETKEY=$minio_secretkey

BEABEE_EMAIL_PROVIDER=sendgrid
BEABEE_EMAIL_SETTINGS_APIKEY=SG.???

BEABEE_NEWSLETTER_PROVIDER=none

EOF

if [[ $name == cnr-* ]]; then
    echo BEABEE_CNR_MODE=true
else
    cat <<EOF
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
EOF

fi

echo
echo ===============================================================
echo
echo -- Database initialisation
echo -- Run each step separately in the psql console on the Postgres container
echo

cat <<EOF
--- 1. Create database and user

CREATE USER "$db_name" WITH PASSWORD '$db_pass';
CREATE DATABASE "$db_name" WITH OWNER "$db_name";

--- 2. Connect to database

\c "$db_name"

--- 3. Setup database

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

--- 4. Post stack migration setup

GRANT SELECT (starts) ON callout TO "beabee-invoices";
GRANT SELECT (id, "contributionMonthlyAmount", "contributionType") ON contact TO "beabee-invoices";
GRANT SELECT ON contact_role TO "beabee-invoices";
GRANT SELECT (id, amount, status, "chargeDate") ON payment TO "beabee-invoices";

EOF

echo
echo ===============================================================
echo
echo -- Storage initialisation
echo -- Run in a bash shell on the MinIO container
echo

cat <<EOF
mc alias set local http://localhost:9000 admin "\$MINIO_ROOT_PASSWORD"

mc mb local/$minio_bucket

cat > policy.json <<EOP
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:ListBucket"],
      "Resource": ["arn:aws:s3:::$minio_bucket"]
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:AbortMultipartUpload",
        "s3:ListMultipartUploadParts",
        "s3:ListBucketMultipartUploads"
      ],
      "Resource": ["arn:aws:s3:::$minio_bucket/*"]
    }
  ]
}
EOP
mc admin policy create local $minio_bucket-rw policy.json

mc admin user add local $minio_user "$minio_secretkey"
mc admin policy attach local $minio_bucket-rw --user $minio_user
EOF


echo
echo ===============================================================
echo
echo -- DNS records
echo -- Send this to the client so they can install the records
echo

cat <<EOF
Type: CNAME
Name: $domain
Value: $name.clients.hive.beabee.io

... add other records from SendGrid
EOF

echo
echo ===============================================================
echo
echo -- Secrets
echo -- Share these secrets to the client using a zero-knowledge encryption service
echo -- \(e.g. Send on Vaultwarden\)
echo

cat <<EOF
## GoCardless

Webhook URL: https://$domain/webhook/gc
Secret: $gc_secret


## Mailchimp

Webhook URL: https://$domain/webhook/mailchimp?secret=$nl_secret
EOF
