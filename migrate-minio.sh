minio_bucket=beabee-$1
minio_user=$minio_bucket
minio_password=$(pwgen -y 24)

cat <<EOF

mc alias set local http://localhost:9000 \$MINIO_ROOT_USER \$MINIO_ROOT_PASSWORD
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

mc admin user add local $minio_user "$minio_password"
mc admin policy attach local $minio_bucket-rw --user $minio_user

####################

mc alias set local http://localhost:9000 \$MINIO_ROOT_USER \$MINIO_ROOT_PASSWORD
mc alias set remote http://minio-minio-1:9000 $minio_user "$minio_password"

mc mirror local/uploads remote/$minio_bucket
EOF
