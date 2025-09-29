import re
import json

def parse_stressng_output(filename):
    with open(filename, 'r') as f:
        content = f.read()

    runs = re.split(r'\nRun \d+: ', content)
    results = []

    for run in runs[1:]:  # 第一个元素是空的
        run_result = {}
        # 提取 run id
        run_id_match = re.match(r'taskset.*stress-ng.*', run)
        run_result['run_cmd'] = run_id_match.group(0) if run_id_match else ''
        # 提取每个 stressor 的数据
        stressor_data = {}
        stressor_pattern = re.compile(
            r'stress-ng: metrc: \[\d+\] (\w+)\s+(\d+)\s+([\d.]+)\s+([\d.]+)\s+([\d.]+)\s+([\d.]+)\s+([\d.]+)'
        )
        for m in stressor_pattern.finditer(run):
            name, bogo_ops, real_time, usr_time, sys_time, bogo_ops_s_real, bogo_ops_s_usr_sys = m.groups()
            stressor_data[name] = {
                'bogo_ops': int(bogo_ops),
                'real_time': float(real_time),
                'usr_time': float(usr_time),
                'sys_time': float(sys_time),
                'bogo_ops_per_s_real': float(bogo_ops_s_real),
                'bogo_ops_per_s_usr_sys': float(bogo_ops_s_usr_sys)
            }
        run_result['stressors'] = stressor_data
        # 提取 run 完成时间
        complete_match = re.search(r'successful run completed in (.+)', run)
        run_result['run_time'] = complete_match.group(1).strip() if complete_match else ''
        results.append(run_result)
    return results

def parse_time_to_seconds(time_str):
    """Convert time string (e.g., '1 min, 19.39 secs') to seconds."""
    time_match = re.match(r'(?:(\d+)\s*min[s]?)?[,\s]*(\d+\.\d+)\s*sec[s]?', time_str)
    if time_match:
        minutes = int(time_match.group(1)) if time_match.group(1) else 0
        seconds = float(time_match.group(2))
        return minutes * 60 + seconds
    return 0

def calculate_averages(data):
    averages = {}
    count = len(data)

    if count == 0:
        return averages

    # Initialize sums for each stressor and field
    stressor_sums = {}
    total_run_time = 0
    for run in data:
        total_run_time += parse_time_to_seconds(run['run_time'])
        for stressor, metrics in run['stressors'].items():
            if stressor not in stressor_sums:
                stressor_sums[stressor] = {
                    'bogo_ops': 0,
                    'real_time': 0,
                    'usr_time': 0,
                    'sys_time': 0,
                    'bogo_ops_per_s_real': 0,
                    'bogo_ops_per_s_usr_sys': 0
                }
            for key in metrics:
                stressor_sums[stressor][key] += metrics[key]

    # Calculate averages
    for stressor, sums in stressor_sums.items():
        averages[stressor] = {key: value / count for key, value in sums.items()}

    averages['run_time'] = total_run_time / count
    return averages

def print_averages_table(averages):
    print("\nAverages (formatted as table):")
    print("{:<15} {:<10} {:<10} {:<10} {:<10} {:<15} {:<15}".format(
        "Stressor", "Bogo Ops", "Real Time", "Usr Time", "Sys Time", "Bogo Ops/s (Real)", "Bogo Ops/s (Usr+Sys)"
    ))
    print("-" * 80)
    for stressor, metrics in averages.items():
        if stressor == 'run_time':
            continue
        print("{:<15} {:<10} {:<10.2f} {:<10.2f} {:<10.2f} {:<15.2f} {:<15.2f}".format(
            stressor,
            metrics['bogo_ops'],
            metrics['real_time'],
            metrics['usr_time'],
            metrics['sys_time'],
            metrics['bogo_ops_per_s_real'],
            metrics['bogo_ops_per_s_usr_sys']
        ))
    print("\nAverage Run Time: {:.2f} seconds".format(averages['run_time']))

if __name__ == '__main__':
    import sys
    filename = sys.argv[1] if len(sys.argv) > 1 else 'input.raw'
    data = parse_stressng_output(filename)
    # 输出为 JSON
    print(json.dumps(data, indent=2, ensure_ascii=False))

    # Calculate and print averages
    averages = calculate_averages(data)
    print_averages_table(averages)
