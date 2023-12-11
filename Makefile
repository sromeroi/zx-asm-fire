all:
	sjasmplus fire.asm && fuse fire.tap

clean:
	rm fire.tap