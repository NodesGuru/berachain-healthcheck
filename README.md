## Berachain Healthcheck Script

This repository contains a healthcheck script for Berachain with integrated support for [Healthchecks.io](https://healthchecks.io/).

### How It Works

1. The script performs a series of health checks (check both consensus and execution states and reference diff).
2. Reports the status to Healthchecks.io using your unique check URL.
3. Use as a cron job or integrate into CI/CD pipelines for automated monitoring.

### Getting Started

1. Create your project and obtain an API key from https://healthchecks.io/
2. Download the script:
```
wget -O $HOME/bera_healthcheck.sh https://raw.githubusercontent.com/NodesGuru/berachain-healthcheck/refs/heads/main/bera_healthcheck.sh
```
3. Set up your Healthchecks.io check URL in the script (edit the `HC_API_KEY` field with the key from healthchecks.io) and optionally set up your actual ports for your nodes (`HC_BEACON_STATUS_URL` and `HC_ETH_TARGET_NODE`):
```
nano $HOME/bera_healthcheck.sh
```
4. Execute the script or schedule it with a cron job:
```
crontab -e
# Add this to the end
*/1 * * * * /bin/bash $HOME/bera_healthcheck.sh >> $HOME/bera_healthcheck.log
```

### Requirements

- Bash
- Consensus (`beacond`) node
- Execution (`geth` / `reth` / etc) node
- https://healthchecks.io/ key
