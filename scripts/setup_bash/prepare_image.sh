#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# prepare_image.sh — Clean system before imaging:
#  • Stop custom services (Sitrad, telemetry)
#  • Reset DEVICE_TOKEN to placeholder
#  • Disconnect from Tailscale
#  • Clear Tailscale node identity (/var/lib/tailscale)
#  • Shutdown after 5-second countdown
###############################################################################

BASEDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENV_FILE="$BASEDIR/send_to_tb/.env"
KILL_SCRIPT="$BASEDIR/scripts/setup_bash/kill_services.sh"

# 1) Stop custom services
echo "Stopping custom services..."
if [[ -x "$KILL_SCRIPT" ]]; then
    "$KILL_SCRIPT"
else
    echo "$KILL_SCRIPT not found or not executable"
fi

# 2) Replace DEVICE_TOKEN with placeholder
echo "Resetting DEVICE_TOKEN in .env..."
if [[ -f "$ENV_FILE" ]]; then
    sed -i 's/^DEVICE_TOKEN=.*/DEVICE_TOKEN=<YOUR_DEVICE_TOKEN>/' "$ENV_FILE"
    echo "→ Updated: $ENV_FILE"
else
    echo ".env file not found: $ENV_FILE"
fi

# 3) Disconnect from Tailscale and clear node identity
echo "Disconnecting and cleaning Tailscale identity..."
sudo tailscale down || true
sudo tailscale logout || true
sudo rm -rf /var/lib/tailscale
sudo tailscaled --cleanup || true

# 4) Final notice before shutdown
echo
echo "Image is now clean and ready to clone."
echo
echo "  - The system will shut down in:"
for i in {5..1}; do
    echo "  -> $i..."
    sleep 1
done

echo " - Shutting down now."
sudo shutdown now
