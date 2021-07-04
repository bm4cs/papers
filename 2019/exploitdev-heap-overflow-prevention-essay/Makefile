all: clean paper

paper:
	pandoc -s -F pandoc-crossref -F pandoc-citeproc --bibliography=paper.bib \
	-V papersize=a4paper -V geometry:margin=1.1in \
	--table-of-contents \
	-s paper.md -o paper.pdf
#	--variable classoption=twocolumn \

clean:
	rm -f *.pdf *.log *.tex

