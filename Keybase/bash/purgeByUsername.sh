#!/bin/bash -e

function usage()
{
 echo "Usage: $0 <team> <username> [topicName] [chatType]";
 echo "Topic name and chat type are optional, and defaults to 'general' and 'chat'"
 echo "Example: $0 treehouse disturbing007";
 echo "Example: $0 treehouse disturbing007 information";
}

if [[ -z $1 || -z $2 ]];
then
  usage
  exit 127
fi

team="$1"
username="$2"
if [[ -z $3 ]]; then topicName="general"; else topicName="$3"; fi
if [[ $4 != "dev" ]]; then chatType="chat"; else chatType="$4"; fi

temporaryDirectory="$(mktemp -d)"
temporaryWorkingFile="$temporaryDirectory/st0"
stageOneFile="$temporaryDirectory/st1"
stageTwoFile="$temporaryDirectory/st2"
stageThreeFile="$temporaryDirectory/st3"
currentPage="first"

echo $temporaryDirectory;

echo "Purging all messages of '$username' on team '$team#$topicName' (chatType: $chatType)"

echo "STAGE 1: Fetching all chat messages of $team#$topicName.";
while [[ $currentPage != "null" ]];
do
  if [[ $currentPage = "first" ]];
    then
      keybase chat api -m "{\"method\": \"read\", \"params\": {\"options\": {\"channel\": {\"name\": \"$team\", \"members_type\": \"team\", \"topic_name\": \"$topicName\"}}}}" > $temporaryWorkingFile;
    else
      keybase chat api -m "{\"method\": \"read\", \"params\": {\"options\": {\"channel\": {\"name\": \"$team\", \"members_type\": \"team\", \"topic_name\": \"$topicName\"}, \"pagination\": {\"num\": 1000, \"next\": \"$currentPage\"}}}}" > $temporaryWorkingFile;
  fi;

 currentPage=$(cat $temporaryWorkingFile | jq -r '.result.pagination.next')
 if [[ $currentPage = "null" ]]; then echo "Processing last page"; else echo "Processing page $currentPage"; fi
 cat $temporaryWorkingFile >> $stageOneFile;
done

echo "STAGE 2: Filtering all messages sent by $username";
cat $stageOneFile | jq -r ".result.messages[].msg | if .sender.username == \"$username\" and .content.type != \"delete\" and .is_ephemeral_expired != true then . else empty end" > $stageTwoFile;

echo "STAGE 3: Generating output JSON (to delete messages)"
cat $stageTwoFile | jq -r "\"\({\"method\": \"delete\", \"params\": {\"options\": {\"conversation_id\": .conversation_id, \"message_id\": .id}}})\"" > $stageThreeFile;

echo "Ready to delete all messages sent by $username."

read -p "Continue (y/n)? " choice
case "$choice" in
  y|Y ) cat $stageThreeFile | keybase chat api;;
  n|N ) exit 0;;
  * ) exit 0;;
esac

exit 0;
