// clang-format off
#include <uapi/linux/ptrace.h>
#include <linux/sched.h>
#include <linux/types.h>


#define SYS_openat 257 // x86_64 syscall number for openat
// #define SYS_open 2   // x86_64 syscall number for open


#define BUFFER_SIZE 32 * 1024 * 1024 // 32MB
#define PGESIZE 4096
#define RINGBUF_PAGES BUFFER_SIZE / PGESIZE
// #define RINGBUF_PAGES 256

#define MAX_ARGS 6
// Use BCC helper macro so the map is generated in a way BCC expects

BPF_RINGBUF_OUTPUT(logs, RINGBUF_PAGES); // 32MB ring buffer

struct audit_log_entry {
    __u64 timestamp;
    __u32 size;
    __u32 pid;
    __u32 syscall_nr;
    __u32 reserved; // padding for alignment
    __u64 args[MAX_ARGS];

    // flexible array member for variable-length dereference data must be last
    __u8 var_data[];
};


/* sys_enter raw tracepoint handler */
int sys_enter_raw(struct bpf_raw_tracepoint_args *ctx) {
    /* cpu filter */
    // u64 cpu_id = bpf_get_smp_processor_id();
    // if ((cpu_id & 0xf) != 7) {
    //     return 0;
    // }

    long syscall_nr = ctx->args[1];

    /* syscalls filter */
    FILTER_PLACEHOLDER
    
    struct pt_regs *regs = (struct pt_regs *)ctx->args[0];

    // u32 alloc_size = sizeof(struct audit_log_entry);

    // if (syscall_nr != SYS_openat) {  // with dereference
    //     // get the 2rd argument (filename pointer) to dereference
    //     alloc_size = sizeof(struct audit_log_entry) + 256; // 256 bytes for filename
    // }
 
    u32 alloc_size = sizeof(struct audit_log_entry) + 256; // 256 bytes reserved for dereference

    struct audit_log_entry *entry = logs.ringbuf_reserve(alloc_size);
    // struct audit_log_entry entry = {};
    if (!entry) {  // failed to reserve space
        return 0;
    }

    entry->timestamp = bpf_ktime_get_ns();
    // entry->size = sizeof(struct audit_log_entry);
    entry->size = alloc_size;
    entry->pid = bpf_get_current_pid_tgid() >> 32;
    entry->syscall_nr = syscall_nr;

    // 从 pt_regs 读取系统调用参数 (Architecture-dependent)
    #ifdef __x86_64__
        bpf_probe_read_kernel(&entry->args[0], sizeof(u64), &regs->di);
        bpf_probe_read_kernel(&entry->args[1], sizeof(u64), &regs->si);
        bpf_probe_read_kernel(&entry->args[2], sizeof(u64), &regs->dx);
        bpf_probe_read_kernel(&entry->args[3], sizeof(u64), &regs->r10);
        bpf_probe_read_kernel(&entry->args[4], sizeof(u64), &regs->r8);
        bpf_probe_read_kernel(&entry->args[5], sizeof(u64), &regs->r9);
    #else
    #error "Unsupported architecture"
    #endif

    if (syscall_nr == SYS_openat) {
        // 2rd argument filepath dereference
        u64 filename_ptr = entry->args[1];
        if (filename_ptr) {
            bpf_probe_read_user_str(&entry->var_data, 256, (const char *)filename_ptr);
        }

        // Zero out unused args
        entry->args[4] = 0;
        entry->args[5] = 0;
    }

    bpf_ringbuf_submit(entry, 0);
    // logs.ringbuf_output(&entry, entry->size, 0);
    return 0;
}
