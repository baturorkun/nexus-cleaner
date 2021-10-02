#!/bin/bash
set -euo pipefail

### ENVs
# Defaults

function usage()
{
    echo "Usages:"
    echo ' Example:
      ./cleaner.sh \
        --nexus-user="admin" \
        --nexus-passwd="admnin-passwd" \
        --nexus-url="https://nexus.domain.com" \
        --gitlab-url="https://gitlab.domain.com" \
        --gitlab-token="78Ybf-edT67-TYoh56" \
        --nexus-keep-tags="STG-1 STG-2" \
        --nexus-filter-images="^myproject-.*$"
'
}

echo "Getting parameters"
set +u
while [ "$1" != "" ]; do
    PARAM=`echo $1 | awk -F= '{print $1}'`
    VALUE=`echo $1 | awk -F= '{print $2}'`
    case $PARAM in
        -h | --help)
            usage
            exit
            ;;
        --gitlab-url)
            GITLAB_URL=$VALUE
            ;;
        --gitlab-token)
            GITLAB_TOKEN=$VALUE
            ;;
        --nexus-user)
            NEXUS_USER=$VALUE
            ;;
         --nexus-passwd)
            NEXUS_PASSWD=$VALUE
            ;;
        --nexus-url)
            NEXUS_URL=$VALUE
            ;;
        --nexus-keep-tags)
            NEXUS_KEEP_TAGS=$VALUE
            ;;
        --nexus-filter-images)
            NEXUS_FILTER_IMAGES=$VALUE
            ;;
        *)
            echo "ERROR: unknown parameter \"$PARAM\""
            usage
            exit 1
            ;;
    esac
    shift
done


if [ -z $GITLAB_URL ]; then
    echo "GITLAB_URL parameter is missing [ --gitlab-url ]"
    exit
fi

if [ -z $GITLAB_TOKEN ]; then
    echo "GITLAB_TOKEN parameter is missing [ --gitlab-token ]"
    exit
fi

if [ -z $NEXUS_USER ]; then
    echo "NEXUS_USER parameter is missing [ --nexus-user ]"
    exit
fi

if [ -z $NEXUS_PASSWD ]; then
    echo "NEXUS_PASSWD parameter is missing [ --nexus-passwd ]"
    exit
fi

if [ -z $NEXUS_URL ]; then
    echo "NEXUS_URL parameter is missing [ --nexus-url ]"
    exit
fi

if [ -z "$NEXUS_KEEP_TAGS" ]; then
    echo "Warning: NEXUS_KEEP_TAGS parameter is missing [ --nexus-keep-tags ]"
    NEXUS_KEEP_TAGS="latest "
else
    NEXUS_KEEP_TAGS="${NEXUS_KEEP_TAGS} latest "
fi

if [ -z "$NEXUS_FILTER_IMAGES" ]; then
    echo "Warning: NEXUS_FILTER_IMAGES parameter is missing [ --nexus-filter-images ]"
    NEXUS_FILTER_IMAGES=" "
else
    NEXUS_FILTER_IMAGES="${NEXUS_FILTER_IMAGES}"
fi

set -u

echo "Getting Nexus Tags..."

NEXUS_TAGS_ARRAY=("")

continuationToken=$(curl -s -u "$NEXUS_USER:$NEXUS_PASSWD" -X GET "$NEXUS_URL/service/rest/v1/search?repository=docker-hosted" | jq -r '.continuationToken')

while true; do

  echo "continuationToken: $continuationToken"

  if [[ "$continuationToken" == "null" ]]; then
      ARR=( $(curl -s -u "$NEXUS_USER:$NEXUS_PASSWD" -X GET "$NEXUS_URL/service/rest/v1/search?repository=docker-hosted" |  jq -r '.items[] | .name + ":" + .version') )
  else
      ARR=( $(curl -s -u "$NEXUS_USER:$NEXUS_PASSWD" -X GET "$NEXUS_URL/service/rest/v1/search?repository=docker-hosted&continuationToken=$continuationToken" | jq -r '.items[] | .name + ":" + .version') )
      continuationToken=$(curl -s -u "$NEXUS_USER:$NEXUS_PASSWD" -X GET "$NEXUS_URL/service/rest/v1/search?repository=docker-hosted&continuationToken=$continuationToken" | jq -r '.continuationToken')
  fi

  NEXUS_TAGS_ARRAY=($(echo ${NEXUS_TAGS_ARRAY[*]}) $(echo ${ARR[*]}))

  if [[ "$continuationToken" == "null" ]]; then
      echo "finished nexus pagination"
      break
  fi

done


GIT_BRANCHES_LIST=$(curl -s --header "PRIVATE-TOKEN: $GITLAB_TOKEN" "$GITLAB_URL/api/v4/projects/2/repository/branches" | jq -r '.[].name' |  cut -f1 -d"-")
GIT_TAGS_LIST=$(curl -s --header "PRIVATE-TOKEN: $GITLAB_TOKEN" "$GITLAB_URL/api/v4/projects/2/repository/tags" | jq -r '.[].name')

# shellcheck disable=SC2066
for OBJ in "${NEXUS_TAGS_ARRAY[@]}"; do
    SRV=$(echo "$OBJ" | cut -d ":" -f1)
    TAG=$(echo "$OBJ" | cut -d ":" -f2)

    echo "SRV: $SRV  // TAG:> $TAG"

    if [[ "$TAG" == *"."* ]]; then
       echo "This is Version"
       LIST=$GIT_TAGS_LIST
    else
       #echo "This is Branch"
       LIST=$GIT_BRANCHES_LIST
    fi

    if [[ $(echo "$LIST" | grep -E "^${TAG}$") ]]; then
        echo "++++++++++++++++++++ $TAG is alive"
    else
        if [[ $(echo "$SRV" | grep -E $NEXUS_FILTER_IMAGES) == "" ]]; then
            echo "* Keep IMAGE : $SRV"
            continue
        fi

        if [[ $(echo "$NEXUS_KEEP_TAGS" | grep -E "$TAG\s") ]]; then
            echo "* Keep TAG : $TAG"
            continue
        fi

        echo "- $TAG is dead. Deleting..."
        IMAGE_SHA=$(curl --silent -I -X GET -H 'Accept: application/vnd.docker.distribution.manifest.v2+json' -u ${NEXUS_USER}:${NEXUS_PASSWD} "${NEXUS_URL}/repository/docker-hosted/v2/${SRV}/manifests/$TAG" | grep Docker-Content-Digest | cut -d ":" -f3 | tr -d '\r')
        echo "DELETE ${TAG} ${IMAGE_SHA}";
        DEL_URL="${NEXUS_URL}/repository/docker-hosted/v2/${SRV}/manifests/sha256:${IMAGE_SHA}"
        #echo $DEL_URL
        RET="$(curl --silent -k -X DELETE -H 'Accept: application/vnd.docker.distribution.manifest.v2+json' -u ${NEXUS_USER}:${NEXUS_PASSWD} $DEL_URL)"
        echo $RET
    fi
done
