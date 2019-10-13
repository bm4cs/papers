#!/bin/sh

tar -czf expdev-essay.tar.gz ./2019-expdev-heap-overflow-prevention
scp expdev-essay.tar.gz root@192.168.1.100:~

