#!/bin/bash

usage(){
    echo
    echo "  ################################################"
    echo
    echo "  -o    Give old hash to replace"
    echo "  -n    Give new hash which replaces the old one"
    echo
    echo "  Example: "
    echo   
    echo "  ./find-replace-hash.sh -o 47d7ffa986d06c530d6660abca775ca7 -n 12345678909876543212354567890987" 
    echo
    echo
    echo
    echo "  ################################################"
    echo
    exit 1
}

if [[ ! $@ =~ ^\-.+ ]];then
  usage
fi

while getopts ":o:n:" opt; do
    case $opt in
        o)
            OLDHASH=$OPTARG
            ;;
        n)
            NEWHASH=$OPTARG
            ;;
        \?)
            echo "Invalid Option: -$OPTARG" >&2
            exit 42
            ;;
        :)
            echo "Option -$OPTARG requires an argument." >&2
            usage
            exit 42
        ;;
    esac
done

#Variables
GIT_TOKEN="75dc5d6e69e2042c832246df8263af428be5a4bd"
#Get conf.d folder inside sensu-server
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SENSUCONF=$(echo "$SCRIPT_DIR")
#File the hash is in 
HASHFILE=$(grep --exclude-dir=".git" -Hirn "$SENSUCONF" -e "$OLDHASH" | cut -d':' -f 1)
GITHASHFILE=$(echo $HASHFILE | tr '/' ' ' | awk '{print $NF}')
#Branch to push to before creating a pull request and merging to master 
GITBRANCH="test/test-pr-merge"

#Check if user input is fine
if [[ $NEWHASH == $OLDHASH ]];then
    echo "New hash equals the old one. Exiting!"
    exit 1
fi 

##Check that input is actually md5 (has 32 characters :D)
if [[ ${#OLDHASH} != "32" ]]; then
    echo "Old MD5 hash not recognized (Your input: $OLDHASH)"
    exit 1
fi

if [[ ${#NEWHASH} != "32" ]]; then
    echo "New MD5 hash not recognized (Your input: $NEWHASH)"
    exit 1
fi

##Checkout master, pull to make sure everything is uptodate & go to new branch
#git checkout master
#git pull 
#git branch -q "$GITBRANCH" > /dev/null 2>&1
#git checkout "$GITBRANCH"


#check if hashfile is located based on the hash
if [[ $HASHFILE ]];then
    echo "Hash located"
else
    echo "Hash not found. Try again"
    exit 1
fi

echo "Replace hash"
sed -i "s/$OLDHASH/$NEWHASH/g" $HASHFILE

echo $HASHFILE
echo $GITHASHFILE

#Push the changed hash to GIT 
git add $HASHFILE
git commit -q -m "Replaced hash for $GITHASHFILE:" -m "Old hash: $OLDHASH" -m "New hash: $NEWHASH"
git push -q -u origin $GITBRANCH

##Create the pull request

#Body for pr
PR_BODY="{ \"title\": \"Updated hash for $GITHASHFILE\", \"head\": \"$GITBRANCH\", \"base\": \"master\" }"
#Create pull request
CURL_GIT_PR=$(curl -s -H "Content-Type: application/json" -H "Authorization: token $GIT_TOKEN" -d "$PR_BODY" https://api.github.com/repos/miikamoi/automatic-pr-merge/pulls)
#Verify pull request is correct 
PR_URL=$(echo "$CURL_GIT_PR" | jq '.html_url')
echo "Pull request: $PR_URL"

#Get pull request
#Filter out pullrequest number
PR_NUM=$(echo "$PR_URL" | tr '/' ' ' | tr '"' ' ' | awk '{print $NF}')

#CURL_GIT_MERGE_PR=$(curl -s -H -X "Content-Type: application/json" -H "Authorization: token $GIT_TOKEN" -d "$MERGE_BODY" PUT https://api.github.com/repos/miikamoi/automatic-pr-merge/pulls/"$PR_NUM"/merge)
CURL_GIT_MERGE_PR=$(curl "https://api.github.com/repos/miikamoi/automatic-pr-merge/pulls/$PR_NUM/merge" -XPUT -H "Authorization: token $GIT_TOKEN" -H "Content-Type: application/json")
#                                                                                                                                                   /repos/:owner  /:repo             /pulls/:number/merge
echo "$CURL_GIT_MERGE_PR"
#
#
#echo "Hash update complete - changes have been committed to master "
