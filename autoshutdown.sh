#!/bin/sh
  DISCORD_WEBHOOK_URL=$1 

  BIN_PATH="/run/current-system/sw/bin"
  webhook() {
    URL="${DISCORD_WEBHOOK_URL}"
    DATA=$($BIN_PATH/cat << EOF
    {
      "username": "Ficsit Corp",
      "embeds": [{
        "title": "AWS Instance Status",
        "description": "Instance is shutting down...",
        "color": "45973"
      }]
    }
EOF
  )
  $BIN_PATH/curl -H "Content-Type: application/json" -X POST -d "$DATA" "$URL"
}

# Function to sum array elements
sumOfArrayElements() {
    sum=0
    for byte in "$@"; do
        sum=$((sum + byte))
    done
    echo "$sum"
}

# Function to check for traffic on a given port
checkForTraffic() {
    PORT_TO_CHECK=$1
    NUMBER_OF_CHECKS=$2
    CONNECTION_BYTES=()

    for ((connections=0; connections<NUMBER_OF_CHECKS; connections++)); do
        CHECK_CONNECTION_BYTES=$($BIN_PATH/ss -luna "( dport = :$PORT_TO_CHECK or sport = :$PORT_TO_CHECK )" | $BIN_PATH/awk '{s+=$2} END {print s}')
        CONNECTION_BYTES+=($CHECK_CONNECTION_BYTES)
    done

    sumOfArrayElements "${CONNECTION_BYTES[@]}"
}

# Function to shut down the system
shutdownSequence() {
    echo "No activity detected. Shutting down."
    systemctl stop satisfactory.service
    systemctl start satisfactory-backup.service
    webhook
    sleep 10
    shutdown -h now
}

# Main function
main() {
    IDLE_COUNTER=0
    TOTAL_IDLE_SECONDS=300
    GAME_PORT=7777
    CHECKS=5

    while [ $IDLE_COUNTER -lt $TOTAL_IDLE_SECONDS ]; do
        ACTIVE_CONNECTIONS=$(checkForTraffic "$GAME_PORT" "$CHECKS")

        if [ "$ACTIVE_CONNECTIONS" -eq 0 ]; then
            IDLE_COUNTER=$((IDLE_COUNTER + 1))
            echo "No connection detected."
        else
            echo "Connection detected."
            IDLE_COUNTER=0
        fi

        sleep 1
    done

    shutdownSequence
}

main
