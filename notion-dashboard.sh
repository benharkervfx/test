#!/bin/bash

RED=$'\033[0;31m'
RESET=$'\033[0m'
GREEN=$'\033[0;32m'
BLUE=$'\033[1;34m'

NOTION_TOKEN="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"
DATABASE_ID="17a31fba2ae4803bbbe0f21a38569735"

response=$(curl -s -X POST "https://api.notion.com/v1/databases/$DATABASE_ID/query" \
  -H "Authorization: Bearer $NOTION_TOKEN" \
  -H "Notion-Version: 2022-06-28" \
  -H "Content-Type: application/json")

clear
echo -e "\n🧾 Notion Dashboard - Updated $(date)\n"

# Extract plain data
plain_output=$(echo "$response" | jq -r '
  .results[] |
  [
    (.properties.Name.title[0].plain_text // "–"),
    (.properties.Gig.select.name // "–"),
    (.properties.Select.select.name // "–"),
    (.properties.Payout.select.name // "–"),
    (.properties["Quoted [unconfirmed]"].number // 0 | tostring),
    (.properties["Invoice [comfirmed]"].number // 0 | tostring)
  ] |
  @tsv')

# Group jobs into arrays
quoted_jobs=()
invoiced_jobs=()
sprint_jobs=()

while IFS=$'\t' read -r name gig status payout quoted invoice; do
  if [[ "$status" == "COMPLETE" ]]; then continue; fi

  line="${name}\t${gig}\t${status}\t${payout}\t${quoted}\t${invoice}"

  if [[ "$status" == "SPRINT" ]]; then
    sprint_jobs+=("${line}")
  elif [[ "$invoice" -gt 0 ]]; then
    invoiced_jobs+=("${line}")
  else
    quoted_jobs+=("${line}")
  fi
done <<< "$plain_output"

# Print sections without box borders

print_section() {
  local section=("$@")
  for row in "${section[@]}"; do
    echo -e "$row"
  done
}

quoted_lines=()
quoted_content=$( {
  echo -e "Name\tGig\tStatus\tPayout\tQuoted (£)\tInvoiced (£)"
  print_section "${quoted_jobs[@]}"
} | column -t -s $'\t' | awk -v green="$GREEN" -v reset="$RESET" 'NR==1 {print; next} {print green $0 reset}' )
if [[ -z "$quoted_content" ]]; then
  quoted_lines+=("No quoted jobs found.")
else
  quoted_lines+=("$quoted_content")
fi

width=$(($(tput cols) - 1))  # Get terminal width and subtract 1
echo -e "\033[42m\033[97m\033[1m❓ QUoooOTED JOBS \033[0m"
echo -e "${quoted_lines[@]}" | column -t -s $'\t'
quoted_total=$(for job in "${quoted_jobs[@]}"; do echo -e "$job"; done | awk -F'\t' '{sum += $5} END {print sum}')
echo -e "\n${GREEN}Estimated Quoted Income: ${RESET} ${WHITE}£${quoted_total}${RESET}"
echo -e "${GREEN}These amounts are being actively discussed with clients and may change${RESET}\n\n"

invoiced_lines=()
invoiced_content=$( {
  echo -e "Name\tGig\tStatus\tPayout\tQuoted (£)\tInvoiced (£)"
  print_section "${invoiced_jobs[@]}"
} | column -t -s $'\t' | awk -v blue="$BLUE" -v reset="$RESET" 'NR==1 {print; next} {print blue $0 reset}' )
if [[ -z "$invoiced_content" ]]; then
  invoiced_lines+=("No invoiced jobs found.")
else
  invoiced_lines+=("$invoiced_content")
fi

echo -e "\033[44m\033[97m\033[1m📮 INVOICED JOBS \033[0m"
echo -e "${invoiced_lines[@]}" | column -t -s $'\t'

invoiced_total=$(for job in "${invoiced_jobs[@]}"; do echo -e "$job"; done | awk -F'\t' '{sum += $6} END {print sum}')
echo -e "\n${BLUE}Estimated Invoiced Income:${RESET} ${WHITE}£${invoiced_total}${RESET}"
echo -e "${BLUE}These are agreed, billable amounts. \nIf they disappear from here then they have been paid.${RESET}\n\n"

sprint_lines=()
sprint_content=$( {
  echo -e "Name\tGig\tStatus\tPayout\tQuoted (£)\tInvoiced (£)"
  print_section "${sprint_jobs[@]}"
} | column -t -s $'\t' | awk -v red="$RED" -v reset="$RESET" 'NR==1 {print; next} {print red $0 reset}' )
if [[ -z "$sprint_content" ]]; then
  sprint_lines+=("No sprint jobs found.")
else
  sprint_lines+=("$sprint_content")
fi

echo -e "\033[41m\033[97m\033[1m🚨 SPRINT JOBS \033[0m"
echo -e "${sprint_lines[@]}" | column -t -s $'\t'
echo -e "${RED}\nThese jobs have been paid in full but Aren't handed off just yet."
sprint_messages=("This is why he is up so laaaate."
                 "Ben is working through the night on these jobs."
                 "This is why you hear the clack of the keyboard late at night."
                 "Ben is still at it, finishing up the sprint jobs."
                 "He genuinely wishes he was a better dad."
                 "One day he'll be a way more attentive husband.")
random_index=$((RANDOM % ${#sprint_messages[@]}))
echo -e "${RED}${sprint_messages[$random_index]}${RESET}"
