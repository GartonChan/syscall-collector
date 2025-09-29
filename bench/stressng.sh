CUR_DIR=$(cd $(dirname $0) && pwd)
ROOT_DIR=$(cd $CUR_DIR/.. && pwd)

######################################################################
CMD="taskset -c 0-5 stress-ng \
  --cpu 2 --cpu-ops 300000 \
  --vm 2 --vm-ops 100000 \
  --io 2 --io-ops 100000 \
  --fork 2 --fork-ops 50000 \
  --hdd 2 --hdd-ops 20000 \
  --metrics-brief"

ITERATIONS=20

for ((i=1;i<=ITERATIONS;i++)); do
    echo "Run $i: $CMD"
    eval $CMD
    echo ""
    sleep 3
done

cd $ROOT_DIR
sudo taskset -c 6-7 python3 my_collector.bpf.py > bench/collect 2>&1 &
collector_pid=$!
sleep 3
echo ""
echo "Started collector with PID: $collector_pid"

cd $CUR_DIR

for ((i=1;i<=ITERATIONS;i++)); do
    echo "Run $i: $CMD"
    eval $CMD
    echo ""
    sleep 3
done

sudo kill -9 $collector_pid



######################################################################
CMD="taskset -c 0-5 stress-ng \
  --cpu 2 --cpu-ops 200000 \
  --vm 2 --vm-ops 100000 \
  --io 2 --io-ops 100000 \
  --fork 2 --fork-ops 50000 \
  --hdd 2 --hdd-ops 20000 \
  --metrics-brief"

ITERATIONS=20

for ((i=1;i<=ITERATIONS;i++)); do
    echo "Run $i: $CMD"
    eval $CMD
    echo ""
    sleep 3
done

cd $ROOT_DIR
sudo taskset -c 6-7 python3 my_collector.bpf.py > bench/collect 2>&1 &
collector_pid=$!
sleep 3
echo ""
echo "Started collector with PID: $collector_pid"

cd $CUR_DIR

for ((i=1;i<=ITERATIONS;i++)); do
    echo "Run $i: $CMD"
    eval $CMD
    echo ""
    sleep 3
done

sudo kill -9 $collector_pid






######################################################################
CMD="taskset -c 0-5 stress-ng \
  --cpu 2 --cpu-ops 100000 \
  --vm 2 --vm-ops 100000 \
  --io 2 --io-ops 100000 \
  --fork 2 --fork-ops 50000 \
  --hdd 2 --hdd-ops 20000 \
  --metrics-brief"

ITERATIONS=20

for ((i=1;i<=ITERATIONS;i++)); do
    echo "Run $i: $CMD"
    eval $CMD
    echo ""
    sleep 3
done

cd $ROOT_DIR
sudo taskset -c 6-7 python3 my_collector.bpf.py > bench/collect 2>&1 &
collector_pid=$!
sleep 3
echo ""
echo "Started collector with PID: $collector_pid"

cd $CUR_DIR

for ((i=1;i<=ITERATIONS;i++)); do
    echo "Run $i: $CMD"
    eval $CMD
    echo ""
    sleep 3
done

sudo kill -9 $collector_pid






######################################################################
CMD="taskset -c 0-5 stress-ng \
  --cpu 2 --cpu-ops 100000 \
  --vm 2 --vm-ops 200000 \
  --io 2 --io-ops 200000 \
  --fork 2 --fork-ops 50000 \
  --hdd 2 --hdd-ops 20000 \
  --metrics-brief"

ITERATIONS=20

for ((i=1;i<=ITERATIONS;i++)); do
    echo "Run $i: $CMD"
    eval $CMD
    echo ""
    sleep 3
done

cd $ROOT_DIR
sudo taskset -c 6-7 python3 my_collector.bpf.py > bench/collect 2>&1 &
collector_pid=$!
sleep 3
echo ""
echo "Started collector with PID: $collector_pid"

cd $CUR_DIR

for ((i=1;i<=ITERATIONS;i++)); do
    echo "Run $i: $CMD"
    eval $CMD
    echo ""
    sleep 3
done

sudo kill -9 $collector_pid