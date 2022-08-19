# `start_kernel`

`reserve_early` 可以视为早期的内存分配器

`__reserve_early` 的多次调用入参如下:

1. 4096 8192 ex trampoline false
2. 24576 28672  trampoline false
3. 16777216 26002580 text data bss false
4. 133058560 134084572 ramdisk false
5. 654336 1048576 bios reserved true
6. 26005504 26034341 brk false
7. 28672 32768 PGTABLE false
8. 32768 36864 BOOTMAP false


如何判断两个段出现重叠?

假设有两个段 [start0,end0) [start1,end1)

如果这两个段不重叠必须满足以下条件里面至少一个

1. end1 <= start0
2. start1 >= end0

否则必然重叠

如何计算没有重叠的部分?

两个段出现重叠必然有 start0 < end1 和 start1 < end0

start0 start1 之间的部分和 end0, end1 之间的部分没有重叠


3. 设置部分内存为保留


4. `cgroup_init_early`

初始化 cgroup 暂时不讨论

5. `tick_init` 的过程

tick-common.c(tick_init) ->  clockevents.c(clockevents_register_notifier) -> spinlock.c(_spin_lock_irqsave) -> spinlock_api_smp.h(__spin_lock_irqsave) -> __raw_local_irq_save -> native_save_fl

clockevents_register_notifier 展开如下:
```c
int clockevents_register_notifier(struct notifier_block *nb)
{
 unsigned long flags;
 int ret;

 do { ({ unsigned long __dummy; typeof(flags) __dummy2; (void)(&__dummy == &__dummy2); 1; }); flags = _spin_lock_irqsave(&clockevents_lock); } while (0);
 ret = raw_notifier_chain_register(&clockevents_chain, nb);
 do { ({ unsigned long __dummy; typeof(flags) __dummy2; (void)(&__dummy == &__dummy2); 1; }); _spin_unlock_irqrestore(&clockevents_lock, flags); } while (0);

 return ret;
}
```

_spin_lock_irqsave 展开如下:

```c
static inline unsigned long __spin_lock_irqsave(spinlock_t *lock)
{
 unsigned long flags;

 do { ({ unsigned long __dummy; typeof(flags) __dummy2; (void)(&__dummy == &__dummy2); 1; }); do { (flags) = __raw_local_irq_save(); } while (0); do { } while (0); } while (0);
 do { } while (0);
 do { } while (0);
# 256 "include/linux/spinlock_api_smp.h"
 __raw_spin_lock_flags(&(lock)->raw_lock, *(&flags));

 return flags;
}
```
