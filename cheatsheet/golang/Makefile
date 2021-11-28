all: clean paper

paper:
	docker run --rm --volume "`pwd`:/data" --user `id -u`:`id -g` pandoc/latex:latest -s \
	-V papersize:a4 -V geometry:margin=0.5in -V fontsize:8pt \
	-s paper.md -o paper.pdf \
	--variable classoption=twocolumn \

clean:
	rm -f *.pdf *.log *.tex

