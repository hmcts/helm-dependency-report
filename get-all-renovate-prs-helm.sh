brew_installed=$(which brew | grep -o brew > /dev/null &&  echo 0 || echo 1)

    if [ $brew_installed = 1 ]; then
        echo "Homebrew is missing. Please install brew before continuing"
        exit 1
    fi

platform=$(uname)

if [ $platform == "Darwin" ]; then

    packages=(coreutils gawk gsed yj jq)

    for i in "${packages[@]}"

    do
        installed=$(which $i | grep -o $i > /dev/null &&  echo 0 || echo 1)
        if [ $installed = 1 ]; then
            echo "${i} is missing! Brew will attempt to install it..."
            brew install ${i}
        else
            awk_command=$(which gawk)
            sed_command=$(which gsed)
            date_command=$(which gdate)
    fi
    done

elif [ $platform == "Linux" ]; then

    packages=(awk sed yj jq)

    for i in "${packages[@]}"

    do
        installed=$(which $i | grep -o $i > /dev/null &&  echo 0 || echo 1)
        if [ $installed = 1 ]; then
            echo "${i} is missing! Brew will attempt to install it..."
            brew install ${i}
        else
            awk_command=$(which awk)
            sed_command=$(which sed)
            date_command=$(which date)
    fi
    done
fi

slack_bot_token=$SLACK_BOT_TOKEN

repos=$(gh search prs "Update Helm release" --owner hmcts --author app/renovate --state=open --created="*..$($date_command --date="7 days ago" +"%Y"-"%m"-"%d")" --sort=created --json repository | jq -r '. | unique_by(.repository.name)' | jq -r '.[].repository.name')

for repo in $(echo "${repos[@]}"); do
    
    team=$(echo $repo | $sed_command 's/\-.*$//')
    
    slackChannel=".${team}.slack.contact_channel"
    
    if [[ "$repo" = *sds-toffee* || "$repo" = *cnp-plum* ]]; then
        contact_channel="#test-ek-3"
        # contact_channel="#platform-operations"
    else
        contact_channel=$(curl -s https://raw.githubusercontent.com/hmcts/cnp-jenkins-config/master/team-config.yml | yq $(echo $slackChannel | tr -d '"'))
    fi

    if [ $contact_channel = null ]; then
        contact_channel="#test-ek-3"
        # contact_channel="#platform-operations"
        message_data="{\"channel\": \"$contact_channel\",\"blocks\": [{\"type\": \"section\",\"text\": {\"type\": \"mrkdwn\",\"text\": \"*Helm dependencies are out of date - <https://github.com/hmcts/$repo|$repo>*\"}},{\"type\": \"section\",\"text\": {\"type\": \"mrkdwn\",\"text\": \"There are renovate pull requests pending review to update helm charts in $repo.\"}},{\"type\": \"section\",\"text\": {\"type\": \"mrkdwn\",\"text\": \"These are needed to keep your app up to date so please review the pull requests at your earliest convenience.\"}},{\"type\": \"section\",\"text\": {\"type\": \"mrkdwn\",\"text\": \":warning: *This message was sent to this channel because a team mapping could not be found for this repo. Please update <https://github.com/hmcts/cnp-jenkins-config/blob/master/team-config.yml|team_config.yaml> so messages get sent to the correct channel*\"}},{\"type\": \"actions\",\"elements\": [{\"type\": \"button\",\"text\": {\"type\": \"plain_text\",\"text\": \"Click here to view pending PRs\",\"emoji\": true},\"url\": \"https://github.com/hmcts/$repo/pulls?q=is%3Apr+is%3Aopen+sort%3Aupdated-desc+author%3Aapp%2Frenovate+Helm+in%3Atitle\"}]}]}"
    elif [ $contact_channel = "#platops-help" ]; then
        contact_channel="#test-ek-3"
        # contact_channel="#platform-operations"
        message_data="{\"channel\":\"$contact_channel\",\"blocks\": [{\"type\": \"section\",\"text\": {\"type\": \"mrkdwn\",\"text\": \"*Helm dependencies are out of date - <https://github.com/hmcts/$repo|$repo>*\"}},{\"type\": \"section\",\"text\": {\"type\": \"mrkdwn\",\"text\": \"There are renovate pull requests pending review to update helm charts in $repo.\"}},{\"type\": \"section\",\"text\": {\"type\": \"mrkdwn\",\"text\": \"These are needed to keep your app up to date so please review the pull requests at your earliest convenience.\"}},{\"type\": \"actions\",\"elements\": [{\"type\": \"button\",\"text\": {\"type\": \"plain_text\",\"text\": \"Click here to view pending PRs\",\"emoji\": true},\"url\": \"https://github.com/hmcts/$repo/pulls?q=is%3Apr+is%3Aopen+sort%3Aupdated-desc+author%3Aapp%2Frenovate+Helm+in%3Atitle\"}]}]}"
    else
        contact_channel="#test-ek-2"
        message_data="{\"channel\":\"$contact_channel\",\"blocks\": [{\"type\": \"section\",\"text\": {\"type\": \"mrkdwn\",\"text\": \"*Helm dependencies are out of date - <https://github.com/hmcts/$repo|$repo>*\"}},{\"type\": \"section\",\"text\": {\"type\": \"mrkdwn\",\"text\": \"There are renovate pull requests pending review to update helm charts in $repo.\"}},{\"type\": \"section\",\"text\": {\"type\": \"mrkdwn\",\"text\": \"These are needed to keep your app up to date so please review the pull requests at your earliest convenience.\"}},{\"type\": \"actions\",\"elements\": [{\"type\": \"button\",\"text\": {\"type\": \"plain_text\",\"text\": \"Click here to view pending PRs\",\"emoji\": true},\"url\": \"https://github.com/hmcts/$repo/pulls?q=is%3Apr+is%3Aopen+sort%3Aupdated-desc+author%3Aapp%2Frenovate+Helm+in%3Atitle\"}]}]}"
    fi

    post_request=$(curl -s -H "Content-type: application/json" \
    --data "$message_data" \
    -H "Authorization: Bearer ${slack_bot_token}" \
    -H application/json \
    -X POST https://slack.com/api/chat.postMessage)

    if [ $(echo $post_request | jq '.ok') = "false" ]; then
        reason=$(echo $post_request | jq -r '.error')
        message_data="{\"channel\": \"#test-ek-2\",\"blocks\": [{\"type\": \"section\",\"text\": {\"type\": \"mrkdwn\",\"text\": \"*Message could not be sent - <https://github.com/hmcts/$repo|$repo>*\"}},{\"type\": \"section\",\"text\": {\"type\": \"mrkdwn\",\"text\": \"A message regarding renovate helm dependencies could not be sent to *$contact_channel*\"}},{\"type\": \"section\",\"text\": {\"type\": \"mrkdwn\",\"text\": \"The error message was: *$reason*\"}},{\"type\": \"section\",\"text\": {\"type\": \"mrkdwn\",\"text\": \":warning: *Please investigate this error and attempt to fix so messages get sent to the correct channel*\"}},{\"type\": \"actions\",\"elements\": [{\"type\": \"button\",\"text\": {\"type\": \"plain_text\",\"text\": \"Click here to view pending PRs\",\"emoji\": true},\"url\": \"https://github.com/hmcts/$repo/pulls?q=is%3Apr+is%3Aopen+sort%3Aupdated-desc+author%3Aapp%2Frenovate+Helm+in%3Atitle\"}]}]}"
        curl -s -H "Content-type: application/json" --data "$message_data" -H "Authorization: Bearer ${slack_bot_token}" -H application/json -X POST https://slack.com/api/chat.postMessage
    fi

done
