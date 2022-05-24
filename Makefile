all:
	zig build

run:
	./zig-cache/bin/slides test.sld > shit.log 2>&1
