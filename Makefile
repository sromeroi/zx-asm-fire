all:
	sjasmplus --syntax=f fire.asm && fuse fire.tap

clean:
	rm fire.tap