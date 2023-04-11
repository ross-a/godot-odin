#!/bin/sh

~/dev/Odin/odin test example.odin -file
~/dev/Odin/odin build example_class.odin -file -debug -build-mode:shared

cp ./example_class.so ./demo/bin/libgdexample.linux.template_debug.x86_64.so
