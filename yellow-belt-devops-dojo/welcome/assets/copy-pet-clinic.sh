#!/bin/bash

#
# Globals
#
GITHUB="github.dxc.com"
DEBUG=false
COLQUESTION="\u001b[36m"
COLINFO="\u001b[37m"
COLLOGS="\u001b[35m"
COLRESET="\u001b[m"
REPO=pet-clinic

if [ "$DEBUG" = false ] ; then
  CURL_NODEBUG="-sS"
fi

# Install Python pre-req
echo -e "${COLINFO}Installing dependencies...${COLRESET}"
2>/dev/null 1>/dev/null python3 -m pip install pyyaml requests

#
# Ask for GitHub PAT
#
echo -e "${COLQUESTION}Please create and enter a Personal Access Token from ${GITHUB} at https://${GITHUB}/settings/tokens:${COLRESET}"
read TOKEN
export TOKEN

echo -e "${COLLOGS}Fetching your details from GitHub...${COLRESET}"

SHORTNAME=$(curl ${CURL_NODEBUG} -H "Authorization: token ${TOKEN}" -X GET https://${GITHUB}/api/v3/user | jq -r '.login')
export SHORTNAME

EMAIL=$(curl ${CURL_NODEBUG} -H "Authorization: token ${TOKEN}" -X GET https://${GITHUB}/api/v3/user | jq -r '.email//empty')
if [ -z "$EMAIL" ]; then
  EMAIL=${SHORTNAME}@dxc.com
fi
export EMAIL

git config --global user.email "${EMAIL}"

check_credentials()
{
curl ${CURL_NODEBUG} -H "Authorization: token $TOKEN" -X GET https://${GITHUB}/api/v3/ | grep "current_user_url"
CREDS_NOT_OK=$?
if [ $CREDS_NOT_OK -ne 0 ]; then
  echo -e "${COLQUESTION}Error: it seems that your credentials are invalid. Please use your GitHub user account and a Personal Access Token with 'repo' and 'admin:repo_hook' scopes at https://github.dxc.com/settings/tokens/new ${COLRESET}"
  exit -1
fi
}
check_credentials

pet_clinic_copy()
{
echo -e "${COLINFO}Copying Pet-Clinic Git repository to user's account ..${COLRESET}"
echo -e "${COLLOGS}"

rm -fr /tmp/${REPO}
git clone https://$TOKEN@${GITHUB}/devops-dojo/${REPO}.git /tmp/${REPO}
cd /tmp/${REPO}
rm -fR .git
git init
git remote add origin https://$SHORTNAME:$TOKEN@${GITHUB}/${SHORTNAME}/${REPO}.git
git add -f .
git commit -m "Initial commit for Pet Clinic application"
git push origin master
cd -
}

# Check if user's copy of repository already exists
echo -e "${COLLOGS}"
curl ${CURL_NODEBUG} -H "Authorization: token $TOKEN" -X GET https://${GITHUB}/api/v3/repos/$SHORTNAME/$REPO/contents/Jenkinsfile | grep "Not Found"
REPO_DOES_NOT_EXIST=$?
if [ $REPO_DOES_NOT_EXIST -eq 0 ]; then
  curl ${CURL_NODEBUG} -H "Authorization: token $TOKEN" -X POST --data "{\"name\":\"${REPO}\"}" https://${GITHUB}/api/v3/user/repos | grep "Not Found"
  USER_HAS_NO_ACCESS_TO_REPO=$?
  if [ $USER_HAS_NO_ACCESS_TO_REPO -eq 0 ]; then
    echo -e "${COLQUESTION}Error: it seems that your credentials are invalid. As per the instructions please use your GitHub user account and a Personal Access Token with 'repo' and 'admin:repo_hook' scopes at https://github.dxc.com/settings/tokens/new ${COLRESET}"
    exit 1
  else
    pet_clinic_copy
  fi
else
  echo -e "${COLINFO}Repository" https://${GITHUB}/${SHORTNAME}/${REPO} "already exists. Skipping.${COLRESET}"
fi

# Provision GitHub issue labels
python3 ./github-labels.py github-labels.yaml

# Provision user stories in GitHub
python3 ./github-issues.py github-issues.yaml

# Ready!
touch /tmp/petclinic_ready
echo -e "${COLINFO}You are all set! Click on 'CONTINUE'.${COLRESET}"
