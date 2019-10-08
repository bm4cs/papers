all: clean paper

paper:
	pandoc -s \
	-V papersize=a4paper -V geometry:margin=1.25in \
	-s paper.md -o paper.pdf \
	--variable classoption=twocolumn \

clean:
	rm -f *.pdf *.log *.tex

