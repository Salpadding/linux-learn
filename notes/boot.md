# `head_32.S` 

以下几点值得注意

- gcc 允许在汇编代码中使用宏
- 在汇编代码中引用宏不可以有UL等后缀,但是在c语言中引用需要,所以有了这样的如下代码



```c
// _AC(0, UL) 在.S 文件中会展开为 0, 在 c语言中会展开为0UL
#define __PAGE_OFFSET		_AC(CONFIG_PAGE_OFFSET, UL)
#ifdef __ASSEMBLY__
#define _AC(X,Y)	X
#else
#define __AC(X,Y)	(X##Y)
#define _AC(X,Y)	__AC(X,Y)
#endif
```

- 尚未开启分页, System.map 中的符号大多是 0xc 开头的 virtual address
- pa 宏展开后其实就是,作用是把 virutal address 地址转换成 physical address 在未开启分页的情况下只能使用 physical address
- PAE 默认没有开启
- 页表加载好了以后 就不需要通过 pa 宏解引用 System.map 里面的符号了

```c
#define pa(X) ((X) - 0xC0000000)
```


- `per_cpu__gdt_page` 是通过宏定义的, 位于 arch/x86/kernel/cpu/common.c

1. 加载内核定义的 gdt，防止依赖于 bootloader 的 gdt

System.map 中 `D boot_gdt_descr` 的值当成一个 `u16*` 解引用得到结果是 31, 说明 gdt 有 (31+1)/8 = 4 项
`boot_gdt_desc+2` 当成 `u32*` 进行解引用得到 0x1730e40, 把 0x1730e40 当成 `u64*` 进行数组索引得到

[0,0,0x00cf9a000000ffff,0x00cf92000000ffff] 可以看到 gdt selector (2<<3) 是内核代码段, (3<<3) 是内核数据段, 代码 `movl $(__BOOT_DS), %eax` `movl %eax, %ds` 就是在设置段寄存器 


2. 清空 `__bss` 段

`__bss` 段不会出现在编译好的内核文件中,所以编译器不负责初始化,需要在运行时初始化


```asm
/*
    清空 direction flag
    设置 eax = 0
    计算 ecx = (__bss_stop - __bss_start) / 2
    执行 rep; stosl 把 edi 开始的内存赋值为0
*/
cld
xorl %eax,%eax
movl $pa(__bss_start),%edi
movl $pa(__bss_stop),%ecx
subl %edi,%ecx
shrl $2,%ecx
rep ; stosl
```


3. 拷贝启动参数和命令行参数

linux 对 bootloader 的要求是 esi 要指向 `boot_params`, 具体定义可以参考[这里](https://www.kernel.org/doc/html/latest/x86/boot.html#bit-boot-protocol)

`boot_params` 的结构可以参考[这里](https://www.kernel.org/doc/html/latest/x86/zero-page.html)

```asm
movl $pa(boot_params),%edi
movl $(PARAM_SIZE/4),%ecx
cld
rep
movsl
movl pa(boot_params) + NEW_CL_POINTER,%esi
andl %esi,%esi
jz 1f			# No comand line
movl $pa(boot_command_line),%edi
movl $(COMMAND_LINE_SIZE/4),%ecx
rep
movsl
```


4. 设置页表

```asm
// 以下代码会把 
// [0,4M) 映射到 [0,4M)
// [PAGE_OFFSET,PAGE_OFFSET+4M) 映射到 [0,4M)
// 4M 不固定取决于内核大小 // 为什么右移20 因为 (__PAGE_OFFSET >> 22) << 2 = __PAGE_OFFSET >> 20 
// >> 22 得到的是索引 而 page directory 每个格子的大小是 4byte 所以还要左移两位
// 我们只需要创建一个 page table 然后填充到 page directory 的两处格子就好了
page_pde_offset = (__PAGE_OFFSET >> 20);

    // __brk_base 是页表的地址,要放到页目录里面
	movl $pa(__brk_base), %edi
	movl $pa(swapper_pg_dir), %edx
	movl $PTE_IDENT_ATTR, %eax
10:
	leal PDE_IDENT_ATTR(%edi),%ecx		/* Create PDE entry */
	movl %ecx,(%edx)			/* Store identity PDE entry */
	movl %ecx,page_pde_offset(%edx)		/* Store kernel PDE entry */
    // 以上代码把 swapper_pg_dir 设置为页目录的地址
    // 并且把第一个页目录设置为  __brk_base + 0x67
	addl $4,%edx // 后续可能要分配新的 pde 所以在这里加4

    // 一个页表有 1024 个格子 所以循环 1024 次
	movl $1024, %ecx
11:
	stosl // 往格子里面填 eax
	addl $0x1000,%eax
	loop 11b

    // 分配
	movl $pa(_end) + MAPPING_BEYOND_END + PTE_IDENT_ATTR, %ebp
	cmpl %ebp,%eax
	jb 10b
```


这里的要点:

目前还没有开启MMU,页表占用的内存只能线性分配,这块内存的起始地址就是 `__brk_base`, 当页表创建完成后把页表的结束地址加上 `PAGE_OFFSET` 填到 _brk_end 里,把页的数量填充到 max_pfn_mapped 里面


5. 加载页表


```asm
	movl $pa(swapper_pg_dir),%eax
	movl %eax,%cr3		/* set the page table pointer.. */
	movl %cr0,%eax
	orl  $X86_CR0_PG,%eax
	movl %eax,%cr0		/* ..and set paging (PG) bit */

    // 重置 eip 刷新指令流水线
    // 这里没有用 pa宏了,而且是 ljmp
	ljmp $__BOOT_CS,$1f	/* Clear prefetch and normalize %eip */
1:
    // 重新设置栈指针
    // 栈指针的尾端定义在了 arch/x86/kernel/init_task.c 里面了
    // 这一块内存是编译器分配的
	/* Set up the stack pointer */
	lss stack_start,%esp
```


6. 初始化 idt

idt 数组定义在了 arch/x86/kernel/traps.c 中

```c
gate_desc idt_table[NR_VECTORS] __page_aligned_data = { { { { 0, 0 } } }, };
```

这里初始化的 idt 没有什么实际意义



7. cpu类型检测,重新设置gdt指向per_cpu__gdt_page,跳转到 i386_start_kernel
