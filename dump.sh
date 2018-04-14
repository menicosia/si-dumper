#!/bin/bash -u

## Relies on environment variables:
# VCAP_SERVICES
# s3Bucket
# s3AccessKey
# s3SecretKey

if [ "XX" = "${VCAP_SERVICES}XX" ]; then
   echo "Required environment variable: VCAP_SERVICES"
   exit 1
fi
if [ "XX" = "${s3Bucket}XX" ]; then
   echo "Required environment variable: s3Bucket"
   exit 1
fi
if [ "XX" = "${s3AccessKey}XX" ]; then
   echo "Required environment variable: s3AccessKey"
   exit 1
fi
if [ "XX" = "${s3SecretKey}XX" ]; then
   echo "Required environment variable: s3SecretKey"
   exit 1
fi

P_MYSQL=$(echo $VCAP_SERVICES | jq -r '.["p-mysql"][]')
USERNAME=$(echo $P_MYSQL | jq -r .credentials.username)
PASSWORD=$(echo $P_MYSQL | jq -r .credentials.password)
HOSTNAME=$(echo $P_MYSQL | jq -r .credentials.hostname)
DATABASE=$(echo $P_MYSQL | jq -r .credentials.name)
INSTANCE=$(echo $P_MYSQL | jq -r .name)

dateStamp=`date +"%Y%m%d-%H%M"`
dateValue=`date -R`
tmpDir="/var/tmp"
objectName="${dateStamp}-output.sql"
filePath="${tmpDir}/${objectName}"
resource="/${s3Bucket}/${objectName}"
contentType="text/plain"
stringToSign="PUT\n\n${contentType}\n${dateValue}\n${resource}"
signature=`echo -en ${stringToSign} | openssl sha1 -hmac ${s3SecretKey} -binary | base64`

./mysqldump -u$USERNAME -p$PASSWORD -h$HOSTNAME $DATABASE --single-transaction > ${filePath}

curl -i -X PUT -T "${filePath}" \
          -H "Host: ${s3Bucket}.s3.amazonaws.com" \
          -H "Date: ${dateValue}" \
          -H "Content-Type: ${contentType}" \
          -H "Authorization: AWS ${s3AccessKey}:${signature}" \
          https://${s3Bucket}.s3.amazonaws.com/${objectName}

