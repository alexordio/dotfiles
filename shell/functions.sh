function commit() {
  commitMessage="$*"
  git add .
  if [ "$commitMessage" = "" ]; then
    diff_input=$(echo "=== Summary ===" && git diff --cached --stat && \
                 echo -e "\n=== Diff (truncated if large) ===" && \
                 git diff --cached | head -c 50000)
    commitMessage=$(echo "$diff_input" | claude -p \
      "Write a single-line commit message for this diff. Output ONLY the message, no quotes, no explanation, no markdown.")
    echo ""
    echo "Suggested: $commitMessage"
    echo -n "[Enter] accept / [e] edit / [c] cancel: "
    read choice
    case "$choice" in
      e|E)
        read -e -i "$commitMessage" -p "Message: " commitMessage
        git commit -m "$commitMessage"
        ;;
      c|C)
        echo "Cancelled"
        return 1
        ;;
      *)
        git commit -m "$commitMessage"
        ;;
    esac
    return
  fi
  eval "git commit -a -m '${commitMessage}'"
}