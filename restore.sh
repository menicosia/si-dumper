#!/bin/bash -ux

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

dateValue=`date -R`
contentType="text/plain"
fileList="/var/tmp/fileList.$$"

listRequest="GET\n\n${contentType}\n${dateValue}\n/${s3Bucket}/"

signature1=`echo -en ${listRequest} | openssl sha1 -hmac ${s3SecretKey} -binary | base64`

curl -o ${fileList} -s -i -X GET \
          -H "Host: ${s3Bucket}.s3.amazonaws.com" \
          -H "Content-Type: ${contentType}" \
          -H "Date: ${dateValue}" \
          -H "Authorization: AWS ${s3AccessKey}:${signature1}" \
          https://${s3Bucket}.s3.amazonaws.com/

ARTIFACT=$(cat ${fileList} |./find-files-xml.pl | sort | tail -1)

### PART 2: Restore the backup artifact to our Service Instance

dateValue=`date -R`
artifactRequest="GET\n\n${contentType}\n${dateValue}\n/${s3Bucket}/${ARTIFACT}"

signature2=`echo -en ${artifactRequest} | openssl sha1 -hmac ${s3SecretKey} -binary | base64`

curl -o /var/tmp/${ARTIFACT} -s -X GET \
          -H "Host: ${s3Bucket}.s3.amazonaws.com" \
          -H "Content-Type: ${contentType}" \
          -H "Date: ${dateValue}" \
          -H "Authorization: AWS ${s3AccessKey}:${signature2}" \
          https://${s3Bucket}.s3.amazonaws.com/${ARTIFACT}