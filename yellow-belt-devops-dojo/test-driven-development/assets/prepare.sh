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
WELCOME_URL=https://github.dxc.com/pages/GDO-CTO/Katacoda/katacoda/welcome/

if [ "$DEBUG" = false ] ; then
  CURL_NODEBUG="-sS"
fi

#
# Ask for GitHub PAT
#
echo -e "${COLQUESTION}Please create and enter a Personal Access Token from ${GITHUB} at https://${GITHUB}/settings/tokens:${COLRESET}"
read TOKEN
export TOKEN

echo -e "${COLLOGS}Fetching your details from GitHub...${COLRESET}"

SHORTNAME=$(curl ${CURL_NODEBUG} -H "Authorization: token ${TOKEN}" -X GET https://${GITHUB}/api/v3/user | jq -r '.login')
export SHORTNAME

echo $SHORTNAME > /tmp/shortname.txt
echo $TOKEN >> /tmp/shortname.txt

# Check if repository already exists and properly populated
echo -e "${COLLOGS}"
curl ${CURL_NODEBUG} -H "Authorization: token $TOKEN" -X GET https://${GITHUB}/api/v3/repos/$SHORTNAME/$REPO/contents/Jenkinsfile | grep "Not Found"
REPO_DOES_NOT_EXIST=$?
if [ $REPO_DOES_NOT_EXIST -eq 0 ]; then
  echo -e "${COLRESET}> I'm confused..."
  echo -e "> I was expecting to find the pet-clinic repository under your GitHub username and I didn't, or the content does not look right."
  echo -e "> That must be me. But just in case:"
  echo -e "> - Close this Katacoda window: the environment will expire soon and you need ample time to complete the module"
  echo -e "> - Go through the Welcome module which will set everything up for you:"
  echo -e "> $WELCOME_URL"
  exit 1
fi

#
# Add Katacoda Jenkins URL
KatacodaJenkinsUrl=`curl ${CURL_NODEBUG} "https://katacoda.com/metadata/generate-url?port=8080&ip=$(ip addr show ens3 | grep -Po 'inet \K[\d.]+')"`
url="https://${KatacodaJenkinsUrl}"
echo $url >> /tmp/shortname.txt
#
# Create dashboard tab to point to GitHub
#
echo -e "${COLINFO}Preparing tab to link to ${GITHUB}...${COLRESET}"
echo -e "${COLLOGS}"
sed -i "s/github_url/${GITHUB}\/${SHORTNAME}\/pet-clinic/g" ~/nginx/index.html
docker run --name nginx -p 9876:80 -v /root/nginx:/usr/share/nginx/html:ro -d nginx 

#
# Remove existing web hook
#
echo -e "${COLINFO}Configuring your GitHub pet-clinic repository...${COLRESET}"
echo -e "${COLLOGS}"
curl ${CURL_NODEBUG} -H "Authorization: token $TOKEN" -X GET https://${GITHUB}/api/v3/repos/$SHORTNAME/pet-clinic/hooks | grep id | cut -d ":" -f2 | cut -c 1-6> ids.txt

filename="ids.txt"

remove_existing_webhook()
{
while read -r line
do
    name="$line"
        curl ${CURL_NODEBUG} -H "Authorization: token $TOKEN" -X DELETE https://${GITHUB}/api/v3/repos/$SHORTNAME/pet-clinic/hooks/"$line"
done < "$filename"
}
remove_existing_webhook

#
# Bring up Jenkins
#
bringing_up_jenkins()
{
echo -e "${COLINFO}Bringing up Jenkins...${COLRESET}"
echo -e "${COLLOGS}"
# YB docker image updated weekly with security dependencies => only need to do pull in shift left on security module
#docker pull devopsdojo/jenkins-yb:latest
docker run --name jenkins-yb -d -p 8080:8080 -v /var/run/docker.sock:/var/run/docker.sock -v /tmp/shortname.txt:/tmp/shortname.txt devopsdojo/jenkins-yb:latest
}
bringing_up_jenkins

#
# Configure Web hook
#
adding_webhook()
{
echo -e "${COLINFO}Updating GitHub web hook to point to Katacoda Jenkins...${COLRESET}"
echo -e "${COLLOGS}"
JenkinsUrl=`curl ${CURL_NODEBUG} "https://katacoda.com/metadata/generate-url?port=8080&ip=$(ip addr show ens3 | grep -Po 'inet \K[\d.]+')"`

curl ${CURL_NODEBUG} -H "Authorization: token $TOKEN" -X POST --data '{"name": "web","active": true,"events": [ "push", "pull_request" ], "config":{"url": "https://'"$JenkinsUrl"'/github-webhook/","content_type":"json"}}' https://${GITHUB}/api/v3/repos/$SHORTNAME/pet-clinic/hooks
}
adding_webhook

#
# Add user stories in GitHub
#
add_user_stories()
{
  echo -e "${COLINFO}Add user stories in GitHub...${COLRESET}"
  echo -e "${COLLOGS}"
  # Install python pre-reqs
  2>/dev/null 1>/dev/null python3 -m pip install pyyaml requests

  # Provision user stories in GitHub
  python3 ./github-issues.py github-issues.yaml

  echo -e "${COLINFO}Improvement theme added to the backlog: https://${GITHUB}/${SHORTNAME}/pet-clinic/issues${COLRESET}"
}
add_user_stories

#
# Wait for Jenkins to be up
#
wait_for_jenkins()
{
  echo -e "${COLINFO}Waiting for Jenkins to come up...${COLRESET}"
  echo -e "${COLLOGS}"

  for i in {1..60}
  do
    if (( $( curl -s ${JenkinsUrl} | grep -c "Authentication" ) > 0)); then
      touch /tmp/jenkins_ready
      break
    fi
    echo "Retry $i..."
    sleep 5s
  done
}
wait_for_jenkins

echo -e "${COLINFO}You are all set! Click on 'CONTINUE'.${COLRESET}"
