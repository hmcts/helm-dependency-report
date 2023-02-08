oldIFS=$IFS
IFS=$'\n'

brew_installed=$(which brew | grep -o brew > /dev/null &&  echo 0 || echo 1)

    if [ $brew_installed = 1 ]; then
        echo "Homebrew is missing. Please install brew before continuing"
        exit 1
    fi

platform=$(uname)

if [ $platform == "Darwin" ]; then

    packages=(gdate gawk gsed yj jq)

    for i in "${packages[@]}"

    do
        installed=$(which $i | grep -o $i > /dev/null &&  echo 0 || echo 1)
        if [[ $installed = 1 && ${i} != "gdate" ]]; then
            echo "${i} is missing! Brew will attempt to install it..."
            brew install ${i}
        elif [[ $installed = 1 && ${i} = "gdate" ]]; then
            echo "${i} is missing! Brew will attempt to install it..."
            brew install coreutils
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

# get all prs in organisation that have a specific title and created by renovate over a week ago
repos=$(gh search prs "Update Helm release" --owner hmcts --author app/renovate --state=open --created="*..$($date_command --date="7 days ago" +"%Y"-"%m"-"%d")" --sort=created --json repository | jq -r '. | unique_by(.repository.name)' | jq -r '.[].repository.name')

for repo in $(echo "${repos[@]}"); do

    prs=$(gh pr list --author app/renovate --search "Update Helm release" --state open --repo hmcts/$repo --json title,url)

    updates=$(for pr in $(echo "${prs[@]}"); do
    echo $pr | jq -r '.[].title'
    done)

    team=$(echo $repo | $sed_command 's/\-.*$//')
    
    slackChannel=".${team}.slack.contact_channel"
    
    # extract slack contact channel from file
    contact_channel=$(curl -s https://raw.githubusercontent.com/hmcts/cnp-jenkins-config/master/team-config.yml | yq $(echo $slackChannel | tr -d '"'))

    if [[ "$repo" = *sds-toffee* || "$repo" = *cnp-plum* || "$repo" = *chart-* ]]; then
        contact_channel="#platops-help"
    fi

    if [[ "$repo" = *sptribs* ]]; then
        contact_channel="*special-tribunals-dev-channel*"
    fi

    message_data="{\"channel\": \"#dependencies-helm\",\"blocks\": [{\"type\": \"section\",\"text\": {\"type\": \"mrkdwn\",\"text\": \"*Helm dependencies are out of date - <https://github.com/hmcts/$repo|$repo>*\"}},{\"type\": \"section\",\"text\": {\"type\": \"mrkdwn\",\"text\": \"The following updates are pending in $repo:\n\n$updates\"}},{\"type\": \"section\",\"text\": {\"type\": \"mrkdwn\",\"text\": \"You can contact the team that owns this repo via the *$contact_channel* channel on slack.\"}},{\"type\": \"section\",\"text\": {\"type\": \"mrkdwn\",\"text\": \"These are needed to keep your app up to date so please review the pull requests at your earliest convenience.\"}},{\"type\": \"actions\",\"elements\": [{\"type\": \"button\",\"text\": {\"type\": \"plain_text\",\"text\": \"Click here to view all PRs\",\"emoji\": true},\"url\": \"https://github.com/hmcts/$repo/pulls?q=is%3Apr+is%3Aopen+sort%3Aupdated-desc+author%3Aapp%2Frenovate+Helm+in%3Atitle\"}]}]}"

    # send slack message
    curl -s -H "Content-type: application/json" \
    --data "$message_data" \
    -H "Authorization: Bearer ${slack_bot_token}" \
    -H application/json \
    -X POST https://slack.com/api/chat.postMessage

done

IFS=$oldIFS