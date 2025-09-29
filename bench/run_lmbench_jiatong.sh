#!/usr/bin/env bash
# Usage: ./run_lmbench.sh [on|off]

set -e
DPUAUDIT_STATE=${1:-on}
CUR_DIR=$(cd $(dirname $0); pwd)
ROOT_DIR=$(cd $CUR_DIR/..; pwd)
LMBENCH_BIN_DIR=/usr/lib/lmbench/bin/x86_64-linux-gnu

# 更合理的参数配置
ITERATIONS=20
WARMUP_ITERATIONS=10
CPU_CORE=7

run_benchmarks() {
    local prefix="$1"
    echo "Running lmbench $prefix..."
    
    # Process creation latency
    nice -n -20 taskset -c $CPU_CORE $LMBENCH_BIN_DIR/lat_proc -N $ITERATIONS -W $WARMUP_ITERATIONS fork
    
    # System call latencies with different parameters
    nice -n -20 taskset -c $CPU_CORE $LMBENCH_BIN_DIR/lat_syscall -N $ITERATIONS -W $WARMUP_ITERATIONS null
    nice -n -20 taskset -c $CPU_CORE $LMBENCH_BIN_DIR/lat_syscall -N $ITERATIONS -W $WARMUP_ITERATIONS stat /tmp/testfile
    nice -n -20 taskset -c $CPU_CORE $LMBENCH_BIN_DIR/lat_syscall -N $ITERATIONS -W $WARMUP_ITERATIONS read /tmp/testfile
    nice -n -20 taskset -c $CPU_CORE $LMBENCH_BIN_DIR/lat_syscall -N $ITERATIONS -W $WARMUP_ITERATIONS write /tmp/testfile
    nice -n -20 taskset -c $CPU_CORE $LMBENCH_BIN_DIR/lat_syscall -N $ITERATIONS -W $WARMUP_ITERATIONS open /tmp/testfile
}

# 检查 eBPF collector 是否启动成功
check_collector_status() {
    local pid=$1
    local max_wait=10
    local count=0
    
    while [ $count -lt $max_wait ]; do
        if kill -0 $pid 2>/dev/null; then
            # 检查 collector 是否真的在工作（可选）
            if [ -f "bench/collect.log" ] && [ -s "bench/collect.log" ]; then
                echo "Collector started successfully (PID: $pid)"
                return 0
            elif [ $count -gt 3 ]; then
                # 给一些时间让日志文件生成
                echo "Collector process running but no log output yet"
                return 0
            fi
        else
            echo "Error: Collector process failed to start"
            return 1
        fi
        count=$((count + 1))
        sleep 1
    done
    
    echo "Warning: Collector status uncertain"
    return 0
}

# 清理函数
cleanup_collector() {
    local pid=$1
    if [ -n "$pid" ]; then
        echo "Cleaning up collector process (PID: $pid)..."
        
        # 优雅关闭
        sudo kill -TERM $pid 2>/dev/null || true
        sleep 2
        
        # 强制关闭
        if kill -0 $pid 2>/dev/null; then
            sudo kill -9 $pid 2>/dev/null || true
        fi
        
        # 清理可能的子进程
        sudo pkill -f "my_collector.bpf.py" 2>/dev/null || true
        
        # 等待进程结束
        wait $pid 2>/dev/null || true
        echo "Collector cleanup completed"
    fi
}

# 设置陷阱处理，确保脚本异常退出时也能清理
trap 'cleanup_collector $collector_pid' EXIT

cd $CUR_DIR

# 确保系统稳定
echo "Preparing system for benchmarking..."
sync
echo 3 | sudo tee /proc/sys/vm/drop_caches > /dev/null  # 清理系统缓存
sleep 2

# 确保 bench 目录存在
mkdir -p $CUR_DIR/bench

# Disable DPUaudit baseline
run_benchmarks "with DPUaudit disabled"

if [ "$DPUAUDIT_STATE" == "on" ]; then
    echo "Running lmbench with DPUaudit enabled..."
    
    # 检查 eBPF 脚本是否存在
    if [ ! -f "$ROOT_DIR/my_collector.bpf.py" ]; then
        echo "Error: eBPF collector script not found at $ROOT_DIR/my_collector.bpf.py"
        exit 1
    fi
    
    cd $ROOT_DIR
    
    # 启动 collector
    echo "Starting eBPF collector..."
    sudo taskset -c 0-3 python3 $ROOT_DIR/my_collector.bpf.py > $CUR_DIR/bench/collect.log 2>&1 &
    collector_pid=$!
    
    # 检查 collector 启动状态
    if ! check_collector_status $collector_pid; then
        echo "Failed to start collector, skipping DPUaudit test"
        exit 1
    fi
    
    cd $CUR_DIR
    
    # 运行测试
    run_benchmarks "with DPUaudit enabled"
    
    # 清理collector进程
    cleanup_collector $collector_pid
    collector_pid=""  # 清空变量避免重复清理
fi

echo "Benchmark completed!"
echo "Results saved in: $CUR_DIR/bench/"
