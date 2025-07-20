#!/bin/bash
# Simple wrapper to start services and exit terminal

~/ai-services/ai-services.sh start

echo ""
echo "🎉 All services are now running in the background!"
echo "You can safely close this terminal window."
echo ""
echo "To manage services later:"
echo "  ~/ai-services/ai-services.sh status"
echo "  ~/ai-services/ai-services.sh stop"
echo "  ~/ai-services/ai-services.sh logs"
