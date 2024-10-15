HC_DEBUG=false
HC_API_KEY="YOUR_HEALTHCHECKS_IO_KEY"

# Beacon
HC_BEACON_STATUS_URL="http://localhost:26657/status" # Consensus RPC port
HC_BEACON_TMP_PREV_LATEST_BLOCK_PATH="/tmp/hc_beacon_bera_prev_block_height.tmp"
HC_BEACON_SERVICE_NAME="beacond"

# Execution
HC_ETH_TARGET_NODE="http://127.0.0.1:8545"
HC_ETH_REFERENCE_NODE="https://evm-1.testnet.bera-v2.nodes.guru:443"
HC_ETH_REFERENCE_HEIGHT_DIFF_THRESHOLD=10
HC_ETH_CHAIN_ID="0x138d6"
HC_ETH_TMP_PREV_BLOCK_PATH="/tmp/hc_eth_bera_prev_block_height.tmp"

HC_ETH_SYNCING=$(curl -s -H "Content-Type: application/json" -d '{"id":1, "jsonrpc":"2.0", "method": "eth_syncing","params": []}' $HC_ETH_TARGET_NODE | jq .result)
HC_ETH_CHAINID=$(curl -s -H "Content-Type: application/json" -d '{"id":1, "jsonrpc":"2.0", "method": "eth_chainId","params": []}' $HC_ETH_TARGET_NODE | jq .result)
HC_ETH_NET=$(curl -s -H "Content-Type: application/json" -d '{"id":1, "jsonrpc":"2.0", "method": "net_listening","params": []}' $HC_ETH_TARGET_NODE | jq .result)
HC_ETH_LATENCY_SECONDS=$(curl -s -H "Content-Type: application/json" -d '{"id":1, "jsonrpc":"2.0", "method": "net_listening","params": []}' -w "%{time_total}" -o /dev/null -s "$HC_ETH_TARGET_NODE")
HC_ETH_LATENCY_MS=$(echo "$HC_ETH_LATENCY_SECONDS * 1000" | bc -l | xargs printf "%.3f\n" | cut -d'.' -f1)

HC_ETH_SYNCING_CURRENT_BLOCK=$(echo $HC_ETH_SYNCING | jq -r ".currentBlock")
HC_ETH_SYNCING_HIGHEST_BLOCK=$(echo $HC_ETH_SYNCING | jq -r ".highestBlock")
[[ ! -z "$HC_DEBUG" && "$HC_DEBUG" == true ]] && echo $HC_ETH_SYNCING $HC_ETH_SYNCING_CURRENT_BLOCK $HC_ETH_SYNCING_HIGHEST_BLOCK $HC_ETH_CHAINID $HC_ETH_NET $HC_ETH_LATENCY_SECONDS $HC_ETH_LATENCY_MS

# Execution
HC_ETH_BLOCK_HEIGHT_RAW=$(curl -s $HC_ETH_TARGET_NODE -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":0}' | jq ".result")

HC_ETH_BLOCK_HEIGHT=${HC_ETH_BLOCK_HEIGHT_RAW:3:-1}
((HC_ETH_BLOCK_HEIGHT=16#$HC_ETH_BLOCK_HEIGHT));
[[ ! -z "$HC_DEBUG" && "$HC_DEBUG" == true ]] && echo "DEBUG: Local block height: $HC_ETH_BLOCK_HEIGHT"
HC_ETH_TMP_PREV_BLOCK=$(cat $HC_ETH_TMP_PREV_BLOCK_PATH)
HC_ETH_HEIGHT_DIFF=$(expr $HC_ETH_BLOCK_HEIGHT - $HC_ETH_TMP_PREV_BLOCK)

if [ -z $HC_ETH_TMP_PREV_BLOCK ]; then
    echo "ERROR: Previous block not found or missed"
    HC_RESULT=$((HC_RESULT + 1))
else
    [[ ! -z "$HC_DEBUG" && "$HC_DEBUG" == true ]] && echo "DEBUG: Previous block data found"
fi

# Execution reference check
HC_ETH_BLOCK_REFERENCE_HEIGHT_RAW=$(curl -s $HC_ETH_REFERENCE_NODE -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":0}' | jq ".result")

HC_ETH_BLOCK_REFERENCE_HEIGHT=${HC_ETH_BLOCK_REFERENCE_HEIGHT_RAW:3:-1}
((HC_ETH_BLOCK_REFERENCE_HEIGHT=16#$HC_ETH_BLOCK_REFERENCE_HEIGHT));
[[ ! -z "$HC_DEBUG" && "$HC_DEBUG" == true ]] && echo "DEBUG: Reference block height: $HC_ETH_BLOCK_REFERENCE_HEIGHT"
HC_ETH_REFERENCE_HEIGHT_DIFF=$(expr $HC_ETH_BLOCK_REFERENCE_HEIGHT - $HC_ETH_BLOCK_HEIGHT)
[[ ! -z "$HC_DEBUG" && "$HC_DEBUG" == true ]] && echo "DEBUG: Reference block height diff: $HC_ETH_REFERENCE_HEIGHT_DIFF"

[[ ! -z "$HC_DEBUG" && "$HC_DEBUG" == true ]] && echo "DEBUG: $HC_ETH_BLOCK_HEIGHT $HC_ETH_TMP_PREV_BLOCK $HC_ETH_HEIGHT_DIFF $HC_ETH_REFERENCE_HEIGHT_DIFF"
if [ "$HC_ETH_HEIGHT_DIFF" -gt 0 ]; then
    echo "SUCCESS: Height is increasing (diff $HC_ETH_HEIGHT_DIFF block(s))"
else
    echo "ERROR: Height is not increasing (diff $HC_ETH_HEIGHT_DIFF block(s))"
    HC_RESULT=$((HC_RESULT + 1))
fi

if [ "$HC_ETH_REFERENCE_HEIGHT_DIFF" -lt $HC_ETH_REFERENCE_HEIGHT_DIFF_THRESHOLD ]; then
    echo "SUCCESS: Reference diff is $HC_ETH_REFERENCE_HEIGHT_DIFF block(s) (less than $HC_ETH_REFERENCE_HEIGHT_DIFF_THRESHOLD)"
elif [[ -z $HC_ETH_REFERENCE_HEIGHT_DIFF ]]; then
    echo "ERROR: Empty response from $HC_ETH_REFERENCE_NODE"
else
    echo "ERROR: Reference diff is $HC_ETH_REFERENCE_HEIGHT_DIFF block(s) (greater than $HC_ETH_REFERENCE_HEIGHT_DIFF_THRESHOLD)"
    HC_RESULT=$((HC_RESULT + 1))
fi

echo "$HC_ETH_BLOCK_HEIGHT" > $HC_ETH_TMP_PREV_BLOCK_PATH

# Beacon check
HC_BEACON_LATEST_BLOCK=$(curl -s $HC_BEACON_STATUS_URL | jq -r '.result.sync_info.latest_block_height')
HC_BEACON_PREV_LATEST_BLOCK=$(cat $HC_BEACON_TMP_PREV_LATEST_BLOCK_PATH)
HC_BEACON_LATEST_HEIGHT_DIFF=$(expr $HC_BEACON_LATEST_BLOCK - $HC_BEACON_PREV_LATEST_BLOCK)
[[ ! -z "$HC_DEBUG" && "$HC_DEBUG" == true ]] && echo "DEBUG: Beacon latest block is $HC_BEACON_LATEST_BLOCK, previous latest block is $HC_BEACON_PREV_LATEST_BLOCK"
if [ "$HC_BEACON_PREV_LATEST_BLOCK" -lt $HC_BEACON_LATEST_BLOCK ]; then
    echo "SUCCESS: Beacon previous height $HC_BEACON_PREV_LATEST_BLOCK less than current height $HC_BEACON_LATEST_BLOCK"
elif [[ -z $HC_BEACON_PREV_LATEST_BLOCK ]]; then
    echo "ERROR: Previous latest block from file ($HC_BEACON_TMP_PREV_LATEST_BLOCK_PATH) is empty, pass..."
else
    echo "ERROR: Beacon previous height $HC_BEACON_PREV_LATEST_BLOCK is equal or greater than current height $HC_BEACON_LATEST_BLOCK"
    sudo systemctl restart $HC_BEACON_SERVICE_NAME
    HC_RESULT=$((HC_RESULT + 1))
fi

echo "$HC_BEACON_LATEST_BLOCK" > $HC_BEACON_TMP_PREV_LATEST_BLOCK_PATH

if [ "$HC_ETH_SYNCING" != "false" && "$HC_ETH_SYNCING_CURRENT_BLOCK" != "$HC_ETH_SYNCING_HIGHEST_BLOCK" ] || [ "$HC_ETH_CHAINID" != \"$HC_ETH_CHAIN_ID\" ] || [ "$HC_ETH_NET" != "true" ] || [ "$HC_ETH_LATENCY_MS" -gt 1000 ] || [ "$http_info" != "" ]; then
    echo "ERROR: Something went wrong"
    echo "Syncing:" $HC_ETH_SYNCING
    echo "Chain ID:" $HC_ETH_CHAINID
    echo "Net listening:" $HC_ETH_NET
    echo "Latency (ms):" $HC_ETH_LATENCY_MS
    echo "HTTP info:" $http_info
    HC_RESULT=$((HC_RESULT + 1))
else
    [[ ! -z "$HC_DEBUG" && "$HC_DEBUG" == true ]] && echo "DEBUG: Metrics OK"
fi

# healthchecks.io
if [[ $HC_RESULT -gt 0 ]]; then
    echo "ERROR: Healthcheck failed with $HC_RESULT errors."
    curl -m 10 -4 -fsS --retry 3 --data-raw "$HC_RESULT" https://hc-ping.com/$HC_API_KEY/fail >/dev/null
else
    echo "SUCCESS: Healthcheck passed successfully."
    curl -m 10 -4 -fsS --retry 3 --data-raw "$HC_RESULT" https://hc-ping.com/$HC_API_KEY >/dev/null
fi
