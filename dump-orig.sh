#!/bin/sh -x

## Relies on environment variables:
# VCAP_SERVICES
# s3Bucket
# s3AccessKey
# s3SecretKey

if [ "XX" == "${VCAP_SERVICES}XX" ]; then
   echo "Required environment variable: VCAP_SERVICES"
   exit 1
fi
if [ "XX" == "${s3Bucket}XX" ]; then
   echo "Required environment variable: s3Bucket"
   exit 1
fi
if [ "XX" == "${s3AccessKey}XX" ]; then
   echo "Required environment variable: s3AccessKey"
   exit 1
fi
if [ "XX" == "${s3SecretKey}XX" ]; then
   echo "Required environment variable: s3SecretKey"
   exit 1
fi

USERNAME=$(echo $VCAP_SERVICES | jq -r .[][0].credentials.username)
PASSWORD=$(echo $VCAP_SERVICES | jq -r .[][0].credentials.password)
HOSTNAME=$(echo $VCAP_SERVICES | jq -r .[][0].credentials.hostname)
DATABASE=$(echo $VCAP_SERVICES | jq -r .[][0].credentials.name)
INSTANCE=$(echo $VCAP_SERVICES | jq -r .[][0].name)

date_formatted=`date -R`
tmp_dir="/var/tmp"
file_name="output.sql"
relative_path="/${INSTANCE}/${file_name}"
content_type="text/plain"
stringToSign="PUT\n\n${content_type}\n${date_formatted}\n${relative_path}"
signature=`echo -en ${stringToSign} | openssl sha1 -hmac ${s3SecretKey} -binary | base64`

echo -n "Dumper has mysqldump version: "
./mysqldump --version

# ./mysqldump -u$USERNAME -p$PASSWORD -h$HOSTNAME $DATABASE --single-transaction > ${tmp_dir}/${file_name}

curl -L -X PUT -T "${tmp_dir}/${file_name}" \
  -H "Host: ${s3Bucket}.s3.amazonaws.com" \
  -H "Date: ${date_formatted}" \
  -H "Content-Type: ${content_type}" \
  -H "Authorization: AWS ${s3AccessKey}:${signature}" \
  http://${s3Bucket}.s3.amazonaws.com/${INSTANCE}/${file_name}
