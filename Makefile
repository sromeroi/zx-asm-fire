all:
	../sjasmplus/sjasmplus fire.asm && fuse fire.tap

clean:
	rm fire.tap