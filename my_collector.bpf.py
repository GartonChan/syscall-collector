#!/usr/bin/env python3
from bcc import BPF
import time
import sys
import ctypes

# 获取命令行参数
syscall_filter = sys.argv[1] if len(sys.argv) > 1 else "all"

# raw_tracepoint 版本 - 注意参数读取方式
bpf_text = ""
with open("my_collector.bpf.c", "r") as f:
    bpf_text = f.read()

# 添加过滤条件
print("Using syscall filter:", syscall_filter)

# 系统调用名称映射
syscall_names = {
    0: "read", 1: "write", 2: "open", 3: "close", 4: "stat",
    5: "fstat", 9: "mmap", 10: "mprotect", 11: "munmap",
    21: "access", 39: "getpid", 59: "execve", 60: "exit",
    72: "fcntl", 257: "openat", 262: "newfstatat",
}

if syscall_filter == "all":
    bpf_text = bpf_text.replace("FILTER_PLACEHOLDER", "")
else:
    if not syscall_filter.isdigit():
        print("Error: syscall_filter must be an integer or 'all'.")
        sys.exit(1)
    filter_code = f"if (syscall_nr != {syscall_filter}) return 0;"
    bpf_text = bpf_text.replace("FILTER_PLACEHOLDER", filter_code)

import platform
kernel_version = platform.uname().release
include_path = f"/usr/src/linux-headers-{kernel_version}/include"
# print(f"Using kernel headers from: {include_path}")

b = BPF(text=bpf_text, cflags=["-I/usr/include", f"-I{include_path}"])
b.attach_raw_tracepoint(tp="sys_enter", fn_name="sys_enter_raw")
# 保持程序运行
print(f"Running minimal eBPF program for syscall {syscall_filter}. Press Ctrl+C to exit.")

class AuditLogEntry(ctypes.Structure):
    _fields_ = [
        ("timestamp", ctypes.c_uint64),
        ("size", ctypes.c_uint32),
        ("pid", ctypes.c_uint32),
        ("syscall_nr", ctypes.c_uint32),
        ("reserved", ctypes.c_uint32),
        ("args", ctypes.c_uint64 * 6),
        # var_data 不在这里声明，后续用 size 计算偏移
    ]

def print_event(ctx, data, size):
    event = ctypes.cast(data, ctypes.POINTER(AuditLogEntry)).contents
    base_size = ctypes.sizeof(AuditLogEntry)
    var_data_len = event.size - base_size if event.size > base_size else 0
    print(f"timestamp={event.timestamp} pid={event.pid} syscall={event.syscall_nr} args={[hex(a) for a in event.args]}")
    if var_data_len > 0:
        # 取柔性数组内容
        buf = (ctypes.c_char * var_data_len).from_address(data + base_size)
        # 尝试解码为字符串
        try:
            s = buf.raw.split(b'\0', 1)[0].decode(errors='replace')
        except Exception:
            s = str(buf.raw)
        print(f"  var_data(str): {s}")

def fake_event(ctx, data, size):
    # print("Fake event received")
    pass
    
# 注册 ringbuf 回调
b["logs"].open_ring_buffer(fake_event)

try:
    while True:
        b.ring_buffer_poll(timeout=1000)
except KeyboardInterrupt:
    pass

