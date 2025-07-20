#!/bin/bash
# Mac AI Services - Background daemon script

SERVICES_DIR="$HOME/ai-services"
PID_DIR="$SERVICES_DIR/pids"
LOG_DIR="$SERVICES_DIR/logs"

# Create directories
mkdir -p "$PID_DIR" "$LOG_DIR"

# Function to start service as daemon
start_service() {
    local name=$1
    local dir=$2
    local port=$3
    local service_name=$(echo "$name" | tr ' ' '_' | tr '[:upper:]' '[:lower:]')
    
    echo "Starting $name (port $port) as daemon..."
    
    cd "$SERVICES_DIR/$dir"
    
    # Start service in background, redirect output to log, save PID
    source "$SERVICES_DIR/venv/bin/activate"
    nohup python server.py > "$LOG_DIR/${service_name}.log" 2>&1 &
    echo $! > "$PID_DIR/${service_name}.pid"
    
    echo "Started $name with PID $! (log: $LOG_DIR/${service_name}.log)"
}

# Function to stop all services
stop_services() {
    echo "Stopping all AI services..."
    
    for pidfile in "$PID_DIR"/*.pid; do
        if [ -f "$pidfile" ]; then
            pid=$(cat "$pidfile")
            service_name=$(basename "$pidfile" .pid)
            
            if kill -0 "$pid" 2>/dev/null; then
                echo "Stopping $service_name (PID: $pid)..."
                kill "$pid"
                rm "$pidfile"
            else
                echo "$service_name was not running"
                rm "$pidfile"
            fi
        fi
    done
    
    echo "All services stopped."
}

# Function to check service status
check_status() {
    echo "Mac AI Services Status:"
    echo "======================"
    
    for pidfile in "$PID_DIR"/*.pid; do
        if [ -f "$pidfile" ]; then
            pid=$(cat "$pidfile")
            service_name=$(basename "$pidfile" .pid)
            
            if kill -0 "$pid" 2>/dev/null; then
                echo "✅ $service_name is running (PID: $pid)"
            else
                echo "❌ $service_name is not running"
                rm "$pidfile"
            fi
        fi
    done
    
    echo ""
    echo "Service URLs:"
    echo "- Ollama: http://192.168.14.99:11434"
    echo "- MLX Text Generation: http://192.168.14.99:8000"
    echo "- Stable Diffusion: http://192.168.14.99:8001"
    echo "- Unified Gateway: http://192.168.14.99:9000"
    echo ""
    echo "Logs available in: $LOG_DIR"
}

# Function to show logs
show_logs() {
    local service=$1
    if [ -z "$service" ]; then
        echo "Available log files:"
        ls -la "$LOG_DIR"/*.log 2>/dev/null || echo "No log files found"
        echo ""
        echo "Usage: $0 logs <service_name>"
        echo "Example: $0 logs mlx_text_generation"
        return
    fi
    
    local logfile="$LOG_DIR/${service}.log"
    if [ -f "$logfile" ]; then
        echo "Showing logs for $service (last 50 lines):"
        echo "=========================================="
        tail -50 "$logfile"
    else
        echo "Log file not found: $logfile"
    fi
}

# Main script logic
case "$1" in
    start)
        echo "Starting Mac AI Services with Apple Silicon GPU + Unified Memory..."
        
        # Check if virtual environment exists
        if [ ! -d "$SERVICES_DIR/venv" ]; then
            echo "❌ Virtual environment not found at $SERVICES_DIR/venv"
            echo "Please run the setup script first."
            exit 1
        fi
        
        # Start all services as daemons
        start_service "MLX Text Generation" "mlx" "8000"
        sleep 2
        start_service "Stable Diffusion" "diffusion" "8001"
        sleep 2
        
        # Start gateway
        echo "Starting API Gateway (port 9000) as daemon..."
        cd "$SERVICES_DIR/gateway"
        source "$SERVICES_DIR/venv/bin/activate"
        nohup python gateway.py > "$LOG_DIR/api_gateway.log" 2>&1 &
        echo $! > "$PID_DIR/api_gateway.pid"
        echo "Started API Gateway with PID $!"
        
        echo ""
        echo "🚀 All Mac AI services started as background daemons!"
        echo ""
        echo "Available services:"
        echo "- Ollama (already running): http://192.168.14.99:11434"
        echo "- MLX Text Generation: http://192.168.14.99:8000" 
        echo "- Stable Diffusion: http://192.168.14.99:8001"
        echo "- Unified Gateway: http://192.168.14.99:9000"
        echo ""
        echo "Commands:"
        echo "  $0 status    - Check service status"
        echo "  $0 stop      - Stop all services"
        echo "  $0 restart   - Restart all services"
        echo "  $0 logs      - Show available logs"
        echo "  $0 logs <service> - Show specific service logs"
        echo ""
        echo "✨ You can now close this terminal - services will keep running!"
        ;;
        
    stop)
        stop_services
        ;;
        
    restart)
        echo "Restarting Mac AI Services..."
        stop_services
        sleep 3
        $0 start
        ;;
        
    status)
        check_status
        ;;
        
    logs)
        show_logs "$2"
        ;;
        
    *)
        echo "Mac AI Services Manager"
        echo "======================"
        echo ""
        echo "Usage: $0 {start|stop|restart|status|logs}"
        echo ""
        echo "Commands:"
        echo "  start    - Start all AI services as background daemons"
        echo "  stop     - Stop all running services"
        echo "  restart  - Restart all services"
        echo "  status   - Show status of all services"
        echo "  logs     - Show available log files"
        echo "  logs <service> - Show logs for specific service"
        echo ""
        echo "Examples:"
        echo "  $0 start"
        echo "  $0 status"
        echo "  $0 logs mlx_text_generation"
        echo "  $0 stop"
        ;;
esac
