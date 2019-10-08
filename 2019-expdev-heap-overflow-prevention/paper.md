---
title: "Protecting the Heap"
subtitle: "Exploit Development (ZEIT8042) Major Essay"
date: "September 2019"
author: "Benjamin Simmonds (5233344) -- UNSW Canberra"
abstract: "So it turns out the heap is dangerous."
---


<!-- Assessment 4: Major Essay 30%.
• Individual.
• Due Saturday 25 October 2019
• Length not to exceed 3000 words.
• Students are to examine the effectiveness of a
modern exploit mitigation control at a technical
level, specifically addressing current academic 
and industry literature pertaining to the
strengths and weaknesses of the control. -->



# Introduction





# Literature Review

The *heap* is a place in computer memory, made available to every program. The heap, unlike stack managed memory, shines when the use of the memory is not known until the program is actually running (i.e. runtime). That is, heap memory can be dynamically allocated and deallocated on request by the program.

Ultimately it's the responsibility of the kernel to fulfill these memory allocation requests as the come in. Managing the heap is not as simple as it may seem. The individual pieces of the heap that are in use, versus those that are free, must be carefully tracked.

It common for allocators to store this tracking metadata at the beginning of each memory chunk requested. In the case of the glibc `ptmalloc` heap allocator, will shortly see the specific data structures that facilitate its heap chunk accounting.

When it comes to dealing with heap memory as part of a C program, the heap is conveniently abstracted away by `stdlib.h` through the `malloc` and `free` functions. This rids the need for application programmers to having to continually solve the problem of heap management and accounting. While `malloc` and `free` provide the high level interface to working with heap memory, the actual kernel is requested to make this happen through the `sbrk` and `mmap` system calls.

From section 2 (Linux Programmer's Manual) of the man pages:

> `brk()` and `sbrk()` change the location of the program break, which defines the end of the process's data segment (i.e., the program break is the first location after the end of the uninitialized data segment). Increasing the program break has the effect of allocating memory to the process; decreasing the break deallocates memory.

> `mmap()` creates a new mapping in the virtual address space of the calling process. The starting address for the new mapping is specified in addr.


These two kernel memory management related primitives, provide the raw instruments needed to make a heap allocator.

When the allocator finds its starting to run low on memory to satisfy the `malloc` needs of the program, it escalates the matter with the kernel using the `mmap()` and/or `brk()` system calls, requesting to either map in additional virtual address space or adjust the size of the data segment.



Allocators abstract the heap memory, and provides in between caching layer so that the kernel doesn't have to get involved every time heap memory is allocated or freed. When a block of previously allocated memory is freed, it returned to `ptmalloc` which organises in a free list, in the case of `ptmalloc` these are known as *bins*. When a subsequent memory request is made, `ptmalloc` will scan its bins for a free block of the size needed. If it fails to locate a free block of the appropriate size, elevates to the kernel to ask for more memory.





While there is no single defacto heap allocator, most platforms congrete around one:

* `dlmalloc` Doug Lea's general purpose allocator, the original glibc implementation
* `ptmalloc` the GNU/Linux glibc present day (since 2006) multi-threaded allocator
* `jemalloc` FreeBSD
* `tcmalloc` Google
* `libumem` Sun Solaris
* 






A simple program, that involves 2 threads that request memory from the heap allocator, used to showcase some of multi-threaded features of the glibc `ptmalloc` implementation:

```c
#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>
#include <unistd.h>
#include <sys/types.h>

void* threadFunc(void* arg) {
  printf("Before malloc in thread 1\n");
  getchar();
  char* addr = (char*) malloc(1000);
  printf("After malloc and before free in thread 1\n");
  getchar();
  free(addr);
  printf("After free in thread 1\n");
  getchar();
}

int main() {
  pthread_t t1;
  void* s;
  int ret;
  char* addr;

  printf("Per thread heap arena example [%d]\n",getpid());
  printf("Before malloc in main thread\n");
  getchar();
  addr = (char*) malloc(1000);
  printf("After malloc and before free in main thread\n");
  getchar();
  free(addr);
  printf("After free in main thread\n");
  getchar();
  ret = pthread_create(&t1, NULL, threadFunc, NULL);
  if(ret)
  {
    printf("Thread creation error\n");
    return -1;
  }
  ret = pthread_join(t1, &s);
  if(ret)
  {
    printf("Thread join error\n");
    return -1;
  }
  return 0;
}
```



Before `addr = (char*) malloc(1000)` is called by the program, can see no heap memory allocation:

    # cat /proc/2663/maps
    08048000-08049000 r-xp 00000000 08:01 653369     /root/code/arena/arena
    08049000-0804a000 rw-p 00000000 08:01 653369     /root/code/arena/arena
    b757b000-b757c000 rw-p 00000000 00:00 0
    b757c000-b76d8000 r-xp 00000000 08:01 395842     /lib/i386-linux-gnu/i686/cmov/libc-2.13.so
    b76d8000-b76d9000 ---p 0015c000 08:01 395842     /lib/i386-linux-gnu/i686/cmov/libc-2.13.so
    ...
    b7726000-b7727000 r-xp 00000000 00:00 0          [vdso]
    b7727000-b7743000 r-xp 00000000 08:01 391702     /lib/i386-linux-gnu/ld-2.13.so
    b7743000-b7744000 r--p 0001b000 08:01 391702     /lib/i386-linux-gnu/ld-2.13.so
    b7744000-b7745000 rw-p 0001c000 08:01 391702     /lib/i386-linux-gnu/ld-2.13.so
    bfe99000-bfeba000 rw-p 00000000 00:00 0          [stack]


However straight after `malloc` is invoked, as can be seen below, the magic of the `brk()` syscall in action is witnessed, which creates a heap segment by adjusting the program break location. The heap segement in this case is placed just on top of the libc mapped program code (0xb757c000).

    # cat /proc/2663/maps
    08048000-08049000 r-xp 00000000 08:01 653369     /root/code/arena/arena
    08049000-0804a000 rw-p 00000000 08:01 653369     /root/code/arena/arena
    08c6a000-08c8b000 rw-p 00000000 00:00 0          [heap]
    b757b000-b757c000 rw-p 00000000 00:00 0
    b757c000-b76d8000 r-xp 00000000 08:01 395842     /lib/i386-linux-gnu/i686/cmov/libc-2.13.so
    b76d8000-b76d9000 ---p 0015c000 08:01 395842     /lib/i386-linux-gnu/i686/cmov/libc-2.13.so
    ...
    b7726000-b7727000 r-xp 00000000 00:00 0          [vdso]
    b7727000-b7743000 r-xp 00000000 08:01 391702     /lib/i386-linux-gnu/ld-2.13.so
    b7743000-b7744000 r--p 0001b000 08:01 391702     /lib/i386-linux-gnu/ld-2.13.so
    b7744000-b7745000 rw-p 0001c000 08:01 391702     /lib/i386-linux-gnu/ld-2.13.so
    bfe99000-bfeba000 rw-p 00000000 00:00 0          [stack]

Unpacking this memory mapping further, can see the heap segment seems quite large, given only 1000 bytes was requested:

    08c6a000-08c8b000 rw-p 00000000 00:00 0          [heap]

In decimal, equates to 135,168 bytes (or 132KB):

    0x08c8b000 - 0x08c6a000 = 135168
    132 * 1024 = 135168


While seeing the highlevel heap segments is useful, visualising the specific chunks on the heap would be even more useful. Using gdb paired with `libheap` (@libheap) extension library adds heap visualisation abilities to gdb, here can see two chunks exist on the heap, the special *top chunk*, and the 1000 (0x3f0) byte chunk that was requested using `malloc`:

gdb-peda$ heapls
           ADDR             SIZE            STATUS
sbrk_base  0x804a000
chunk      0x804a000        0x3f0           (inuse)
chunk      0x804a3f0        0x20c10         (top)
sbrk_end   0x804a000



## Arenas

It turns out looking at `malloc.c` that 132KB of heap memory was reserved, regardless that only 1000 bytes was initally requested. This continigous block of memory is known commonly by heap allocators as the *main arena*. The `ptmalloc` allocator will utilise and manage memory from the *main arena* for future allocation requests that come in, re-allocated previously used memory that is no longer needed and growing or shrinking the *main arena* by adjusting the heap segment break location.

The *arena* enables allocators abstract the continguous block of memory used to service heap requests, and provides an in-between caching layer so that the kernel doesn't have to get involved every time heap memory is allocated or freed. When a block of previously allocated memory is freed, it returned to `ptmalloc` which organises in a free list, in the case of `ptmalloc` these are known as *bins*. When a subsequent memory request is made, `ptmalloc` will scan its bins for a free block of the size needed. If it fails to locate a free block of the appropriate size, elevates to the kernel to ask for more memory.

What is facinating about the `ptmalloc` allocator, is that when another thread `pthread_create(&t1, NULL, threadFunc, NULL)` makes a memory request using `malloc`, is that a completely new heap segment is created specifically for use by the thread, as can be seen below:

    # cat /proc/2685/maps
    08048000-08049000 r-xp 00000000 08:01 653369     /root/code/arena/arena
    08049000-0804a000 rw-p 00000000 08:01 653369     /root/code/arena/arena
    0804a000-0806b000 rw-p 00000000 00:00 0          [heap]
    b7635000-b7636000 ---p 00000000 00:00 0
    b7636000-b7e37000 rw-p 00000000 00:00 0
    b7e37000-b7f93000 r-xp 00000000 08:01 395842     /lib/i386-linux-gnu/i686/cmov/libc-2.13.so

This new thread specific heap segment is commonly referred to as the *thread arena*.

By splitting out heap segments for threads (i.e. thread arenas), allows `ptmalloc` to allocate and free heap memory in parallel, without blocking on memory operations being performance on the same *arena*.

It doesn't however make sense to create a *thread arena* for each new thread that comes along, that wants to deal with heap memory. The economics of the overheads of allocating and managing separate *thread arenas* versus sharing the same *thread arenas* must be weighed up.

In the case of `ptmalloc`, which is a general purpose allocator, there are limits imposed on the number of *thread arena*'s that can be allocated to a single program:

* For 32-bit chips: 2 x cores
* For 64-bit chips: 8 x cores

A program running on a single core 32-bit system, will have a *main arena* and up to 2 *thread arena*'s. If the program had 4 threads all allocating and freeing heap, threads A and B would share the first *thread arena*, while the other threads C and D share the second *thread arena*. Although some contention may arise, the `ptmalloc` implementors consider this a reasonable tradeoff.


## ptmalloc (glibc)


From documentation embedded in glibc `malloc.c` source file:

This is not the fastest, most space-conserving, most portable, or most tunable malloc ever written. However it is among thefastest while also being among the most space-conserving, portable and tunable. Consistent balance across these factors results ina good general-purpose allocator for malloc-intensive programs.

The main properties of the algorithms are:

* For large (>= 512 bytes) requests, it is a pure best-fit allocator, with ties normally decided via FIFO (i.e. least recently used).
* For small (<= 64 bytes by default) requests, it is a caching allocator, that maintains pools of quickly recycled chunks.
* In between, and for combinations of large and small requests, it does the best it can trying to meet both goals at once.
* For very large requests (>= 128KB by default), it relies on system memory mapping facilities, if supported.



A seemingly simple program that requests 512 bytes from the `ptmalloc` heap allocator.

```c
#include <stdlib.h>

int main()
{
  char* a = malloc(512);
  free(a);
}
```

Tracing the kernel syscalls that are invoked, can see that `mmap2()` and `brk()` feature heavily:

    # strace ./simple
    execve("./simple", ["./simple"], [/* 16 vars */]) = 0
    brk(0)                                  = 0x8b5a000
    access("/etc/ld.so.nohwcap", F_OK)      = -1 ENOENT (No such file or directory)
    mmap2(NULL, 8192, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_ANONYMOUS, -1, 0) = 0xb7707000
    access("/etc/ld.so.preload", R_OK)      = -1 ENOENT (No such file or directory)
    open("/etc/ld.so.cache", O_RDONLY)      = 3
    fstat64(3, {st_mode=S_IFREG|0644, st_size=17310, ...}) = 0
    mmap2(NULL, 17310, PROT_READ, MAP_PRIVATE, 3, 0) = 0xb7702000
    close(3)                                = 0
    access("/etc/ld.so.nohwcap", F_OK)      = -1 ENOENT (No such file or directory)
    open("/lib/i386-linux-gnu/i686/cmov/libc.so.6", O_RDONLY) = 3
    read(3, "\177ELF\1\1\1\0\0\0\0\0\0\0\0\0\3\0\3\0\1\0\0\0\240o\1\0004\0\0\0"..., 512) = 512
    fstat64(3, {st_mode=S_IFREG|0755, st_size=1437864, ...}) = 0
    mmap2(NULL, 1452408, PROT_READ|PROT_EXEC, MAP_PRIVATE|MAP_DENYWRITE, 3, 0) = 0xb759f000
    mprotect(0xb76fb000, 4096, PROT_NONE)   = 0
    mmap2(0xb76fc000, 12288, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_FIXED|MAP_DENYWRITE, 3, 0x15c) = 0xb76fc000
    mmap2(0xb76ff000, 10616, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_FIXED|MAP_ANONYMOUS, -1, 0) = 0xb76ff000
    close(3)                                = 0
    mmap2(NULL, 4096, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_ANONYMOUS, -1, 0) = 0xb759e000
    set_thread_area({entry_number:-1 -> 6, base_addr:0xb759e8d0, limit:1048575, seg_32bit:1, contents:0, read_exec_only:0,     limit_in_pages:1, seg_not_present:0, useable:1}) = 0
    mprotect(0xb76fc000, 8192, PROT_READ)   = 0
    mprotect(0xb7726000, 4096, PROT_READ)   = 0
    munmap(0xb7702000, 17310)               = 0
    brk(0)                                  = 0x8b5a000
    brk(0x8b7b000)                          = 0x8b7b000
    exit_group(0)                           = ?




### Bins and Chunks

The heap is managed in units of *chunk*'s. The size of a *chunk* is not fixed, and often varies depending on what memory allocations are requested. In terms of `ptmalloc` chunks are represented with the `malloc_chunk` data structure:

```c
struct malloc_chunk {
  INTERNAL_SIZE_T      mchunk_prev_size;
  INTERNAL_SIZE_T      mchunk_size;
  struct malloc_chunk* fd;
  struct malloc_chunk* bk;
};
```





In the case of `ptmalloc` the `malloc_state` data structure is used to represent this:

```c
struct malloc_state
{
  /* Fastbins */
  mfastbinptr fastbinsY[NFASTBINS];

  /* Base of the topmost chunk -- not otherwise kept in a bin */
  mchunkptr top;

  /* The remainder from the most recent split of a small request */
  mchunkptr last_remainder;

  /* Normal bins packed as described above */
  mchunkptr bins[NBINS * 2 - 2];

  /* Bitmap of bins */
  unsigned int binmap[BINMAPSIZE];
};
```






run AAAABBBBCCCCDDDDEEEEFFFF 000011112222333344445555










# Common Vulnerabilities

## Heap location randomisation (ASLR)

## 





# Commercial Feasibility



# Conclusion



\pagebreak

# References




