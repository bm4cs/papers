all: clean paper

paper:
	pandoc -s \
	-V papersize=a4paper -V geometry:margin=0.5in \
	-s paper.md -o paper.pdf \
	--variable classoption=twocolumn \

clean:
	rm -f *.pdf *.log *.tex

