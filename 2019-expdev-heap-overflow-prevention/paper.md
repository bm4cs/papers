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

The heap is managed in units of *chunk*'s. The size of a *chunk* is not fixed, and often varies depending on what memory allocations are requested. It common for allocators to store this tracking metadata at the beginning of each memory chunk requested.

When it comes to dealing with heap memory as part of a C program, the heap is conveniently abstracted away by `stdlib.h` through the `malloc` and `free` functions. This rids the need for application programmers to having to continually solve the problem of heap management and accounting. While `malloc` and `free` provide the high level interface to working with heap memory, the actual kernel is requested to make this happen through the `sbrk` and `mmap` system calls.

From section 2 (Linux Programmer's Manual) of the man pages:

> `brk()` and `sbrk()` change the location of the program break, which defines the end of the process's data segment (i.e., the program break is the first location after the end of the uninitialized data segment). Increasing the program break has the effect of allocating memory to the process; decreasing the break deallocates memory.

> `mmap()` creates a new mapping in the virtual address space of the calling process. The starting address for the new mapping is specified in addr.


These two kernel memory management related primitives, provide the raw instruments needed to make a heap allocator.

When the allocator finds its starting to run low on memory to satisfy the `malloc` needs of the program, it escalates the matter with the kernel using the `mmap()` and/or `brk()` system calls, requesting to either map in additional virtual address space or adjust the size of the data segment. A seemingly simple program that requests 512 bytes of heap:

```c
#include <stdlib.h>

int main()
{
  char* a = malloc(512);
  free(a);
}
```

Tracing the kernel syscalls that are involved, can see that `mmap2()` and `brk()` feature heavily:

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


Allocators abstract the heap memory, and provides in between caching layer so that the kernel doesn't have to get involved every time heap memory is allocated or freed. When a block of previously allocated memory is freed, it returned to `ptmalloc` which organises in a free list, in the case of `ptmalloc` these are known as *bins*. When a subsequent memory request is made, `ptmalloc` will scan its bins for a free block of the size needed. If it fails to locate a free block of the appropriate size, elevates to the kernel to ask for more memory.

While there is no single defacto heap allocator, most platforms congrete around one:

* `dlmalloc` Doug Lea's general purpose allocator, the original glibc (GNU/Linux) implementation.
* `ptmalloc2` the present day (since 2006) multi-threaded allocator, the Doug Lea implmentation adapted to multiple threads/arenas by Wolfram Gloger.
* `jemalloc` FreeBSD
* `tcmalloc` Google
* `libumem` Sun Solaris
* 



## Understanding the ptmalloc (glibc) heap


the Doug Lea implmentation adapted to multiple threads/arenas by Wolfram Gloger.

As a general purpose heap allocator provided by glibc, the designers had to strike a balance between performance and memory efficiency. As stated in @glibcsource:

> This is not the fastest, most space-conserving, most portable, or most tunable malloc ever written. However it is among the fastest while also being among the most space-conserving, portable and tunable. Consistent balance across these factors results in a good general-purpose allocator for malloc-intensive programs.

Some properties of the `ptmalloc2` algorithm are:

* For large (>= 512 bytes) requests, it is a pure best-fit allocator, with ties normally decided via FIFO (i.e. least recently used).
* For small (<= 64 bytes by default) requests, it is a caching allocator, that maintains pools of quickly recycled chunks.
* In between, and for combinations of large and small requests, it does the best it can trying to meet both goals at once.
* For very large requests (>= 128KB by default), it relies on system memory mapping (`mmap`) facilities, if supported.

When a chunk is requested, the *first-fit algorithm* will try to find the first chunk that is both free and large enough. Or more concretely @how2heap shows how this deterministic behaviour can be used to control the data at a previously freed allocation:


```c
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main()
{
	fprintf(stderr, "Allocating 2 buffers. They can be large, don't have to be fastbin.\n");
	char* a = malloc(512);
	char* b = malloc(256);
	char* c;

	fprintf(stderr, "1st malloc(512): %p\n", a);
	fprintf(stderr, "2nd malloc(256): %p\n", b);
	fprintf(stderr, "we could continue mallocing here...\n");
	fprintf(stderr, "now let's put a string at a that we can read later \"this is A!\"\n");
	strcpy(a, "this is A!");
	fprintf(stderr, "first allocation %p points to %s\n", a, a);

	fprintf(stderr, "Freeing the first one...\n");
	free(a);

	fprintf(stderr, "We don't need to free anything again. As long as we allocate less than 512, it will end up at %p\n", a);
	fprintf(stderr, "So, let's allocate 500 bytes\n");
	c = malloc(500);
	fprintf(stderr, "3rd malloc(500): %p\n", c);
	fprintf(stderr, "And put a different string here, \"this is C!\"\n");
	strcpy(c, "this is C!");
	fprintf(stderr, "3rd allocation %p points to %s\n", c, c);
	fprintf(stderr, "first allocation %p points to %s\n", a, a);
	fprintf(stderr, "If we reuse the first allocation, it now holds the data from the third allocation.\n");
}
```


Output:

    # ./simple
    Allocating 2 buffers. They can be large, don't have to be fastbin.
    1st malloc(512): 0x8445008
    2nd malloc(256): 0x8445210
    we could continue mallocing here...
    now let's put a string at a that we can read later "this is A!"
    first allocation 0x8445008 points to this is A!
    Freeing the first one...
    We don't need to free anything again. As long as we allocate less than 512, it will end up at 0x8445008
    So, let's allocate 500 bytes
    3rd malloc(500): 0x8445008
    And put a different string here, "this is C!"
    3rd allocation 0x8445008 points to this is C!
    first allocation 0x8445008 points to this is C!
    If we reuse the first allocation, it now holds the data from the third allocation.

This is known as a *use-after-free* vulnerability.


### Multiple threads and arenas

`ptmalloc` being a multi threaded and arena adaption of the original Doug Lea heap allocator, allows it to undertake concurrent heap memory management activities, without blocking one thread while another thread requests a `malloc()` or `free()`.

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



Before `addr = (char*) malloc(1000)` is called by the program, can see no heap memory segment mapping exists for the process:

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


Straight after `malloc` is invoked, as can be seen below, the magic of the `brk()` syscall in action can be witnessed, which creates a heap segment by adjusting the programs break location. The heap segement in this case is placed just on top of the libc mapped program code (0xb757c000).

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


While seeing the highlevel heap segments is useful, visualising the specific chunks within the heap would be even more useful. There are some excellent options available, for example using gdb paired with the `libheap` (@libheap) extension library arms gdb with heap visualisation abilities. Below can see two chunks exist on the heap, the special *top chunk*, and the 1000 (0x3f0) byte chunk that was requested using first `malloc()` in the above program:

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

A program running on a single core 32-bit system, will have a *main arena* and up to 2 *thread arena*'s. If a hypthothetical program had 4 threads, in addition to the main thread, all of which needed to allocate and free heap memory, threads A and B would share the first *thread arena*, while threads C and D share the second *thread arena*. Although some contention may arise, the `ptmalloc` implementors consider this a reasonable tradeoff, against the management overheads of juggling additional *thread arenas*.


In the case of `ptmalloc` the `heap_info` and `malloc_state` data structures are used to represent the concept of an arena.



### Heap header

The **heap_info** represents the allocated memory for a *thread arena* heap allocation. Unlike a *main arena*, which is statically defined as a global variable in `libc.so` data segment, a *thread arena* is materialised at runtime, including it `heap_info` (heap header) and `malloc_state` (arena header). Given this, a *main arena* is never represented with a `heap_info` header.

```c
struct heap_info
{
  mstate ar_ptr; /* Arena for this heap. */
  struct heap_info *prev; /* Previous heap. */
  size_t size;   /* Current size in bytes. */
  size_t mprotect_size;
};
```


### Arena header

**malloc_state** represents an arena (both main and thread), which involves one or more heaps, and the freelist bins which relate to this memory, so that freed memory can be later reallocated.


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




## Chunks

The heap is managed in units of *chunk*'s. The size of a *chunk* is not fixed, and varies based on the sizing of memory allocations requested. In `ptmalloc` chunks are represented with the `malloc_chunk` data structure:

```c
struct malloc_chunk {
  INTERNAL_SIZE_T      mchunk_prev_size;
  INTERNAL_SIZE_T      mchunk_size;
  struct malloc_chunk* fd;
  struct malloc_chunk* bk;
};
```

A heap is divided up into a big chain (linked list) of chunks, each of which has there own chunk header (`malloc_chunk`). Depending on the type of chunk it is, determines how data is stored into the `malloc_chunk` data structure. Types of chunks include:



### Top chunk

Always the first chunk at the top of an arena. It can be allocated, by this is done as a last resort by the allocator, if all free bins have been exhausted.


### Last remainder chunk

When exact free chunk sizes are not available, and there sufficient larger chunks avialable, these large chunks will routinely be split into two by the allocator. The first piece is returned to the requesting program that called `malloc()`, where the other piece becomes a last remainder chunk. Last remainder chunks have the benefit of increasing the memory locality of subsequent memory allocations, which can come as a performance boost.



### Allocated chunk

A chunk that's been reserved for use.

    +----------------------------------+
    |  If prior chunk free, then size  | <---+ chunk
    |  of this chunk, else user data   |
    +----------------------+---+---+---+
    |  The chunk size      | N | M | P |
    +----------------------+---+---+---+
    |                                  | <---+ mem
    |             User data            |
    |                                  |
    +----------------------------------+

If the previous chunk is free (which is doesn't have to be), the size of it is stored in `mchunk_prev_size`, otherwise this is just filled with user data from the previous chunk. Note the last three bits of the chunk size, provide some extra management metadata:

* `N` true if chunk owned by thread arena
* `M` true if chunk allocted by `mmap`
* `P` true if previous chunk is in use (i.e. has been allocated)


### Free chunk

Unlike an allocated chunk, is heap memory that is available for re-allocation. Free chunks can never reside next to another free chunk. The allocator always coalesces adjacent free chunks together.

As can be seen below, a free chunk must always be preceded by an allocated chunk, therefore its `mchunk_prev_size` will always have user data from the previous allocated chunk.


    +-------------------------------+
    |  User data of previous chunk  | <---+ chunk
    +-------------------+---+---+---+
    |  The chunk size   | N | M | P |
    +-------------------+---+---+---+
    |  fd (next chunk in binlist)   | <---+ mem
    +-------------------------------+
    |  bk (prev chunk in binlist)   |
    +-------------------------------+
    |                               |
    |         Unused space          |
    |                               |
    +-------------------------------+

Lastly, a free chunk maintains two pointers, `fd` and `bk`, to the next and previous free chunks stored in the same free bin as the current free chunk, forming a doubly linked list of free chunks. These are *not* simply pointers to the next and previous chunks in memory.



## Bins

In heap management, a *bin* is just a list (linked list) of chunks of unallocated memory. Bins are categorised based on the size of the chunks they hold.


### Fast bins

Manages 10 separate bins, of sizes 16, 24, 32, 40, 48, 56, 64, 72, 80 and 88 bytes. Only free chunks that match the size (including metadata) of the bin can be added to it. For example, only a 48 byte free chunk can be added to the 48 byte fast bin.

```c
typedef struct malloc_chunk *mfastbinptr;

mfastbinptr fastbinsY[]; // Array of pointers to chunks
```

Called *fast bins* because no free chunk coalescing is ever performed on adjacent *fast bin* based free chunks. The result is higher memory fragmentation (due to no compacting occurs) at the tradeoff of increased performance.


### Unsorted, small and large bins

All of these three bins are managed as a single array called `bins`:

```c
typedef struct malloc_chunk* mchunkptr;

mchunkptr bins[]; // Array of pointers to chunks
```

Each bin (i.e. unsorted, small and large) is defined as two values, the head and tail of the list of chunks it is responsible for managing (a singly linked list).

**Unsorted bin**, is a single bin where freed small and large chunks, when later freed again, end up. It exists as a cache, to aid `ptmalloc` to deal with allocation and deallocation requests.

**Small bins**, are managed across 62 separate bins, similar to fast bins, are broken up into distinct sizings (16, 24, ..., 504 bytes). Each contain a doubly linked list of the free chunks it contains. Chunks allocated from small bins may be coalesced together before being assigned to the *unsorted bin*.

**Large bins**, are the last resort for free chunks that don't meet the requirements of the *fast bins* or *small bins*. To loosen requirements *large bins* manages its 63 seperate bins in size ranges. For example its first bin can hold free chunks sized from 512 bytes to 568 bytes. These ranges exponentally widen by groups of 64 bytes, as the bin sizes increase, with the very last bin being able to store the biggest free chunks of all.



Free chunk




* Top chunk
* Last remainder chunk
















# Common Vulnerabilities






TODO: Summarise this ptmalloc security matrix https://heap-exploitation.dhavalkapil.com/diving_into_glibc_heap/security_checks.html





## Heap location randomisation (ASLR)

## 





# Commercial Feasibility



# Conclusion



\pagebreak

# References




